"""

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

"""

from collections import deque

import cocotb
from cocotb.log import SimLog
from cocotb.queue import Queue
from cocotb.triggers import Event, Edge, RisingEdge

import struct

MQNIC_MAX_EVENT_RINGS   = 1
MQNIC_MAX_TX_RINGS      = 32
MQNIC_MAX_TX_CPL_RINGS  = 32
MQNIC_MAX_RX_RINGS      = 8
MQNIC_MAX_RX_CPL_RINGS  = 8

MQNIC_QUEUE_STRIDE        = 0x00000020
MQNIC_CPL_QUEUE_STRIDE    = 0x00000020
MQNIC_EVENT_QUEUE_STRIDE  = 0x00000020

# NIC CSRs
MQNIC_REG_FW_ID                  = 0x0000
MQNIC_REG_FW_VER                 = 0x0004
MQNIC_REG_BOARD_ID               = 0x0008
MQNIC_REG_BOARD_VER              = 0x000C

MQNIC_REG_PHC_COUNT              = 0x0010
MQNIC_REG_PHC_OFFSET             = 0x0014

MQNIC_REG_IF_COUNT               = 0x0020
MQNIC_REG_IF_STRIDE              = 0x0024
MQNIC_REG_IF_CSR_OFFSET          = 0x002C

MQNIC_REG_FPGA_ID                = 0x0040

MQNIC_REG_GPIO_OUT               = 0x0100
MQNIC_REG_GPIO_IN                = 0x0104

MQNIC_REG_GPIO_I2C_0             = 0x0110
MQNIC_REG_GPIO_I2C_1             = 0x0114
MQNIC_REG_GPIO_I2C_2             = 0x0118
MQNIC_REG_GPIO_I2C_3             = 0x011C

MQNIC_REG_GPIO_I2C_SCL_IN        = 0x00000001
MQNIC_REG_GPIO_I2C_SCL_OUT       = 0x00000002
MQNIC_REG_GPIO_I2C_SDA_IN        = 0x00000100
MQNIC_REG_GPIO_I2C_SDA_OUT       = 0x00000200

MQNIC_REG_GPIO_XCVR_0123         = 0x0120
MQNIC_REG_GPIO_XCVR_4567         = 0x0124

MQNIC_REG_GPIO_XCVR_PRSNT_IN          = 0x01
MQNIC_REG_GPIO_XCVR_TX_FAULT_INT_IN   = 0x02
MQNIC_REG_GPIO_XCVR_RX_LOS_IN         = 0x03
MQNIC_REG_GPIO_XCVR_RST_OUT           = 0x10
MQNIC_REG_GPIO_XCVR_TX_DIS_LPMODE_OUT = 0x20
MQNIC_REG_GPIO_XCVR_RS0_OUT           = 0x40
MQNIC_REG_GPIO_XCVR_RS1_OUT           = 0x80

MQNIC_PHC_REG_FEATURES           = 0x0000
MQNIC_PHC_REG_PTP_CUR_FNS        = 0x0010
MQNIC_PHC_REG_PTP_CUR_NS         = 0x0014
MQNIC_PHC_REG_PTP_CUR_SEC_L      = 0x0018
MQNIC_PHC_REG_PTP_CUR_SEC_H      = 0x001C
MQNIC_PHC_REG_PTP_GET_FNS        = 0x0020
MQNIC_PHC_REG_PTP_GET_NS         = 0x0024
MQNIC_PHC_REG_PTP_GET_SEC_L      = 0x0028
MQNIC_PHC_REG_PTP_GET_SEC_H      = 0x002C
MQNIC_PHC_REG_PTP_SET_FNS        = 0x0030
MQNIC_PHC_REG_PTP_SET_NS         = 0x0034
MQNIC_PHC_REG_PTP_SET_SEC_L      = 0x0038
MQNIC_PHC_REG_PTP_SET_SEC_H      = 0x003C
MQNIC_PHC_REG_PTP_PERIOD_FNS     = 0x0040
MQNIC_PHC_REG_PTP_PERIOD_NS      = 0x0044
MQNIC_PHC_REG_PTP_NOM_PERIOD_FNS = 0x0048
MQNIC_PHC_REG_PTP_NOM_PERIOD_NS  = 0x004C
MQNIC_PHC_REG_PTP_ADJ_FNS        = 0x0050
MQNIC_PHC_REG_PTP_ADJ_NS         = 0x0054
MQNIC_PHC_REG_PTP_ADJ_COUNT      = 0x0058
MQNIC_PHC_REG_PTP_ADJ_ACTIVE     = 0x005C

MQNIC_PHC_REG_PEROUT_CTRL         = 0x0000
MQNIC_PHC_REG_PEROUT_STATUS       = 0x0004
MQNIC_PHC_REG_PEROUT_START_FNS    = 0x0010
MQNIC_PHC_REG_PEROUT_START_NS     = 0x0014
MQNIC_PHC_REG_PEROUT_START_SEC_L  = 0x0018
MQNIC_PHC_REG_PEROUT_START_SEC_H  = 0x001C
MQNIC_PHC_REG_PEROUT_PERIOD_FNS   = 0x0020
MQNIC_PHC_REG_PEROUT_PERIOD_NS    = 0x0024
MQNIC_PHC_REG_PEROUT_PERIOD_SEC_L = 0x0028
MQNIC_PHC_REG_PEROUT_PERIOD_SEC_H = 0x002C
MQNIC_PHC_REG_PEROUT_WIDTH_FNS    = 0x0030
MQNIC_PHC_REG_PEROUT_WIDTH_NS     = 0x0034
MQNIC_PHC_REG_PEROUT_WIDTH_SEC_L  = 0x0038
MQNIC_PHC_REG_PEROUT_WIDTH_SEC_H  = 0x003C

# Interface CSRs
MQNIC_IF_REG_IF_ID               = 0x0000
MQNIC_IF_REG_IF_FEATURES         = 0x0004

MQNIC_IF_REG_EVENT_QUEUE_COUNT   = 0x0010
MQNIC_IF_REG_EVENT_QUEUE_OFFSET  = 0x0014
MQNIC_IF_REG_TX_QUEUE_COUNT      = 0x0020
MQNIC_IF_REG_TX_QUEUE_OFFSET     = 0x0024
MQNIC_IF_REG_TX_CPL_QUEUE_COUNT  = 0x0028
MQNIC_IF_REG_TX_CPL_QUEUE_OFFSET = 0x002C
MQNIC_IF_REG_RX_QUEUE_COUNT      = 0x0030
MQNIC_IF_REG_RX_QUEUE_OFFSET     = 0x0034
MQNIC_IF_REG_RX_CPL_QUEUE_COUNT  = 0x0038
MQNIC_IF_REG_RX_CPL_QUEUE_OFFSET = 0x003C
MQNIC_IF_REG_PORT_COUNT          = 0x0040
MQNIC_IF_REG_PORT_OFFSET         = 0x0044
MQNIC_IF_REG_PORT_STRIDE         = 0x0048

MQNIC_IF_FEATURE_RSS             = (1 << 0)
MQNIC_IF_FEATURE_PTP_TS          = (1 << 4)
MQNIC_IF_FEATURE_TX_CSUM         = (1 << 8)
MQNIC_IF_FEATURE_RX_CSUM         = (1 << 9)

# Port CSRs
MQNIC_PORT_REG_PORT_ID                    = 0x0000
MQNIC_PORT_REG_PORT_FEATURES              = 0x0004
MQNIC_PORT_REG_PORT_MTU                   = 0x0008

MQNIC_PORT_REG_SCHED_COUNT                = 0x0010
MQNIC_PORT_REG_SCHED_OFFSET               = 0x0014
MQNIC_PORT_REG_SCHED_STRIDE               = 0x0018
MQNIC_PORT_REG_SCHED_TYPE                 = 0x001C
MQNIC_PORT_REG_SCHED_ENABLE               = 0x0040

MQNIC_PORT_REG_TX_MTU                     = 0x0100
MQNIC_PORT_REG_RX_MTU                     = 0x0200

MQNIC_PORT_REG_TDMA_CTRL                  = 0x1000
MQNIC_PORT_REG_TDMA_STATUS                = 0x1004
MQNIC_PORT_REG_TDMA_TIMESLOT_COUNT        = 0x1008
MQNIC_PORT_REG_TDMA_SCHED_START_FNS       = 0x1010
MQNIC_PORT_REG_TDMA_SCHED_START_NS        = 0x1014
MQNIC_PORT_REG_TDMA_SCHED_START_SEC_L     = 0x1018
MQNIC_PORT_REG_TDMA_SCHED_START_SEC_H     = 0x101C
MQNIC_PORT_REG_TDMA_SCHED_PERIOD_FNS      = 0x1020
MQNIC_PORT_REG_TDMA_SCHED_PERIOD_NS       = 0x1024
MQNIC_PORT_REG_TDMA_SCHED_PERIOD_SEC_L    = 0x1028
MQNIC_PORT_REG_TDMA_SCHED_PERIOD_SEC_H    = 0x102C
MQNIC_PORT_REG_TDMA_TIMESLOT_PERIOD_FNS   = 0x1030
MQNIC_PORT_REG_TDMA_TIMESLOT_PERIOD_NS    = 0x1034
MQNIC_PORT_REG_TDMA_TIMESLOT_PERIOD_SEC_L = 0x1038
MQNIC_PORT_REG_TDMA_TIMESLOT_PERIOD_SEC_H = 0x103C
MQNIC_PORT_REG_TDMA_ACTIVE_PERIOD_FNS     = 0x1040
MQNIC_PORT_REG_TDMA_ACTIVE_PERIOD_NS      = 0x1044
MQNIC_PORT_REG_TDMA_ACTIVE_PERIOD_SEC_L   = 0x1048
MQNIC_PORT_REG_TDMA_ACTIVE_PERIOD_SEC_H   = 0x104C

MQNIC_PORT_FEATURE_RSS                    = (1 << 0)
MQNIC_PORT_FEATURE_PTP_TS                 = (1 << 4)
MQNIC_PORT_FEATURE_TX_CSUM                = (1 << 8)
MQNIC_PORT_FEATURE_RX_CSUM                = (1 << 9)

MQNIC_QUEUE_BASE_ADDR_REG       = 0x00
MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG = 0x08
MQNIC_QUEUE_CPL_QUEUE_INDEX_REG = 0x0C
MQNIC_QUEUE_HEAD_PTR_REG        = 0x10
MQNIC_QUEUE_TAIL_PTR_REG        = 0x18

MQNIC_QUEUE_ACTIVE_MASK = 0x80000000

MQNIC_CPL_QUEUE_BASE_ADDR_REG       = 0x00
MQNIC_CPL_QUEUE_ACTIVE_LOG_SIZE_REG = 0x08
MQNIC_CPL_QUEUE_INTERRUPT_INDEX_REG = 0x0C
MQNIC_CPL_QUEUE_HEAD_PTR_REG        = 0x10
MQNIC_CPL_QUEUE_TAIL_PTR_REG        = 0x18

MQNIC_CPL_QUEUE_ACTIVE_MASK = 0x80000000

MQNIC_CPL_QUEUE_ARM_MASK  = 0x80000000
MQNIC_CPL_QUEUE_CONT_MASK = 0x40000000

MQNIC_EVENT_QUEUE_BASE_ADDR_REG       = 0x00
MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG = 0x08
MQNIC_EVENT_QUEUE_INTERRUPT_INDEX_REG = 0x0C
MQNIC_EVENT_QUEUE_HEAD_PTR_REG        = 0x10
MQNIC_EVENT_QUEUE_TAIL_PTR_REG        = 0x18

MQNIC_EVENT_QUEUE_ACTIVE_MASK = 0x80000000

MQNIC_EVENT_QUEUE_ARM_MASK  = 0x80000000
MQNIC_EVENT_QUEUE_CONT_MASK = 0x40000000

MQNIC_EVENT_TYPE_TX_CPL = 0x0000
MQNIC_EVENT_TYPE_RX_CPL = 0x0001

MQNIC_DESC_SIZE = 16
MQNIC_CPL_SIZE = 32
MQNIC_EVENT_SIZE = 32


class Packet:
    def __init__(self, data=b''):
        self.data = data
        self.timestamp_s = None
        self.timestamp_ns = None
        self.rx_checksum = None

    def __repr__(self):
        return (
            f'{type(self).__name__}(data={self.data}, '
            f'timestamp_s={self.timestamp_s}, '
            f'timestamp_ns={self.timestamp_ns}, '
            f'rx_checksum={self.rx_checksum:#06x})'
        )

    def __iter__(self):
        return self.data.__iter__()

    def __len__(self):
        return len(self.data)

    def __bytes__(self):
        return bytes(self.data)


class EqRing:
    def __init__(self, interface, size, stride, index, hw_regs):
        self.interface = interface
        self.log = interface.log
        self.driver = interface.driver
        self.rc = interface.driver.rc
        self.log_size = size.bit_length() - 1
        self.size = 2**self.log_size
        self.size_mask = self.size-1
        self.stride = stride
        self.index = index
        self.interrupt_index = 0

        self.head_ptr = 0
        self.tail_ptr = 0

        self.hw_ptr_mask = 0xffff
        self.hw_regs = hw_regs

    async def init(self):
        self.log.info("Init EqRing %d (interface %d)", self.index, self.interface.index)

        self.buf_size = self.size*self.stride
        self.buf_region = self.driver.pool.alloc_region(self.buf_size)
        self.buf_dma = self.buf_region.get_absolute_address(0)
        self.buf = self.buf_region.mem

        await self.hw_regs.write_dword(MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG, 0)  # active, log size
        await self.hw_regs.write_dword(MQNIC_EVENT_QUEUE_BASE_ADDR_REG, self.buf_dma & 0xffffffff)  # base address
        await self.hw_regs.write_dword(MQNIC_EVENT_QUEUE_BASE_ADDR_REG+4, self.buf_dma >> 32)  # base address
        await self.hw_regs.write_dword(MQNIC_EVENT_QUEUE_INTERRUPT_INDEX_REG, 0)  # interrupt index
        await self.hw_regs.write_dword(MQNIC_EVENT_QUEUE_HEAD_PTR_REG, self.head_ptr & self.hw_ptr_mask)  # head pointer
        await self.hw_regs.write_dword(MQNIC_EVENT_QUEUE_TAIL_PTR_REG, self.tail_ptr & self.hw_ptr_mask)  # tail pointer
        await self.hw_regs.write_dword(MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_size)  # active, log size

    async def activate(self, int_index):
        self.log.info("Activate EqRing %d (interface %d)", self.index, self.interface.index)

        self.interrupt_index = int_index

        await self.hw_regs.write_dword(MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG, 0)  # active, log size
        await self.hw_regs.write_dword(MQNIC_EVENT_QUEUE_INTERRUPT_INDEX_REG, int_index)  # interrupt index
        await self.hw_regs.write_dword(MQNIC_EVENT_QUEUE_HEAD_PTR_REG, self.head_ptr & self.hw_ptr_mask)  # head pointer
        await self.hw_regs.write_dword(MQNIC_EVENT_QUEUE_TAIL_PTR_REG, self.tail_ptr & self.hw_ptr_mask)  # tail pointer
        await self.hw_regs.write_dword(MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_size | MQNIC_EVENT_QUEUE_ACTIVE_MASK)  # active, log size

    async def deactivate(self):
        await self.hw_regs.write_dword(MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_size)  # active, log size
        await self.hw_regs.write_dword(MQNIC_EVENT_QUEUE_INTERRUPT_INDEX_REG, self.interrupt_index)  # interrupt index

    def empty(self):
        return self.head_ptr == self.tail_ptr

    def full(self):
        return self.head_ptr - self.tail_ptr >= self.size

    async def read_head_ptr(self):
        val = await self.hw_regs.read_dword(MQNIC_EVENT_QUEUE_HEAD_PTR_REG)
        self.head_ptr += (val - self.head_ptr) & self.hw_ptr_mask

    async def write_tail_ptr(self):
        await self.hw_regs.write_dword(MQNIC_EVENT_QUEUE_TAIL_PTR_REG, self.tail_ptr & self.hw_ptr_mask)

    async def arm(self):
        await self.hw_regs.write_dword(MQNIC_EVENT_QUEUE_INTERRUPT_INDEX_REG, self.interrupt_index | MQNIC_EVENT_QUEUE_ARM_MASK)  # interrupt index

    async def process(self):
        if not self.interface.port_up:
            return

        self.log.info("Process event queue")

        await self.read_head_ptr()

        eq_tail_ptr = self.tail_ptr
        eq_index = eq_tail_ptr & self.size_mask

        self.log.info("%d events in queue", self.head_ptr - eq_tail_ptr)

        while (self.head_ptr != eq_tail_ptr):
            event_data = struct.unpack_from("<HH", self.buf, eq_index*self.stride)

            self.log.info("Event data: %s", repr(event_data))

            if event_data[0] == 0:
                # transmit completion
                cq = self.interface.tx_cpl_queues[event_data[1]]
                await self.interface.process_tx_cq(cq)
                await cq.arm()
            elif event_data[0] == 1:
                # receive completion
                cq = self.interface.rx_cpl_queues[event_data[1]]
                await self.interface.process_rx_cq(cq)
                await cq.arm()

            eq_tail_ptr += 1
            eq_index = eq_tail_ptr & self.size_mask

        self.tail_ptr = eq_tail_ptr
        await self.write_tail_ptr()


class CqRing:
    def __init__(self, interface, size, stride, index, hw_regs):
        self.interface = interface
        self.log = interface.log
        self.driver = interface.driver
        self.rc = interface.driver.rc
        self.log_size = size.bit_length() - 1
        self.size = 2**self.log_size
        self.size_mask = self.size-1
        self.stride = stride
        self.index = index
        self.interrupt_index = 0
        self.ring_index = 0

        self.head_ptr = 0
        self.tail_ptr = 0

        self.hw_ptr_mask = 0xffff
        self.hw_regs = hw_regs

    async def init(self):
        self.log.info("Init CqRing %d (interface %d)", self.index, self.interface.index)

        self.buf_size = self.size*self.stride
        self.buf_region = self.driver.pool.alloc_region(self.buf_size)
        self.buf_dma = self.buf_region.get_absolute_address(0)
        self.buf = self.buf_region.mem

        await self.hw_regs.write_dword(MQNIC_CPL_QUEUE_ACTIVE_LOG_SIZE_REG, 0)  # active, log size
        await self.hw_regs.write_dword(MQNIC_CPL_QUEUE_BASE_ADDR_REG, self.buf_dma & 0xffffffff)  # base address
        await self.hw_regs.write_dword(MQNIC_CPL_QUEUE_BASE_ADDR_REG+4, self.buf_dma >> 32)  # base address
        await self.hw_regs.write_dword(MQNIC_CPL_QUEUE_INTERRUPT_INDEX_REG, 0)  # event index
        await self.hw_regs.write_dword(MQNIC_CPL_QUEUE_HEAD_PTR_REG, self.head_ptr & self.hw_ptr_mask)  # head pointer
        await self.hw_regs.write_dword(MQNIC_CPL_QUEUE_TAIL_PTR_REG, self.tail_ptr & self.hw_ptr_mask)  # tail pointer
        await self.hw_regs.write_dword(MQNIC_CPL_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_size)  # active, log size

    async def activate(self, int_index):
        self.log.info("Activate CqRing %d (interface %d)", self.index, self.interface.index)

        self.interrupt_index = int_index

        await self.hw_regs.write_dword(MQNIC_CPL_QUEUE_ACTIVE_LOG_SIZE_REG, 0)  # active, log size
        await self.hw_regs.write_dword(MQNIC_CPL_QUEUE_INTERRUPT_INDEX_REG, int_index)  # event index
        await self.hw_regs.write_dword(MQNIC_CPL_QUEUE_HEAD_PTR_REG, self.head_ptr & self.hw_ptr_mask)  # head pointer
        await self.hw_regs.write_dword(MQNIC_CPL_QUEUE_TAIL_PTR_REG, self.tail_ptr & self.hw_ptr_mask)  # tail pointer
        await self.hw_regs.write_dword(MQNIC_CPL_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_size | MQNIC_CPL_QUEUE_ACTIVE_MASK)  # active, log size

    async def deactivate(self):
        await self.hw_regs.write_dword(MQNIC_CPL_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_size)  # active, log size
        await self.hw_regs.write_dword(MQNIC_CPL_QUEUE_INTERRUPT_INDEX_REG, self.interrupt_index)  # event index

    def empty(self):
        return self.head_ptr == self.tail_ptr

    def full(self):
        return self.head_ptr - self.tail_ptr >= self.size

    async def read_head_ptr(self):
        val = await self.hw_regs.read_dword(MQNIC_CPL_QUEUE_HEAD_PTR_REG)
        self.head_ptr += (val - self.head_ptr) & self.hw_ptr_mask

    async def write_tail_ptr(self):
        await self.hw_regs.write_dword(MQNIC_CPL_QUEUE_TAIL_PTR_REG, self.tail_ptr & self.hw_ptr_mask)

    async def arm(self):
        await self.hw_regs.write_dword(MQNIC_CPL_QUEUE_INTERRUPT_INDEX_REG, self.interrupt_index | MQNIC_CPL_QUEUE_ARM_MASK)  # event index


class TxRing:
    def __init__(self, interface, size, stride, index, hw_regs):
        self.interface = interface
        self.log = interface.log
        self.driver = interface.driver
        self.rc = interface.driver.rc
        self.log_queue_size = size.bit_length() - 1
        self.log_desc_block_size = int(stride/MQNIC_DESC_SIZE).bit_length() - 1
        self.desc_block_size = 2**self.log_desc_block_size
        self.size = 2**self.log_queue_size
        self.size_mask = self.size-1
        self.full_size = self.size >> 1
        self.stride = stride
        self.index = index
        self.cpl_index = 0

        self.head_ptr = 0
        self.tail_ptr = 0
        self.clean_tail_ptr = 0

        self.packets = 0
        self.bytes = 0

        self.hw_ptr_mask = 0xffff
        self.hw_regs = hw_regs

    async def init(self):
        self.log.info("Init TxRing %d (interface %d)", self.index, self.interface.index)

        self.tx_info = [None]*self.size

        self.buf_size = self.size*self.stride
        self.buf_region = self.driver.pool.alloc_region(self.buf_size)
        self.buf_dma = self.buf_region.get_absolute_address(0)
        self.buf = self.buf_region.mem

        await self.hw_regs.write_dword(MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG, 0)  # active, log size
        await self.hw_regs.write_dword(MQNIC_QUEUE_BASE_ADDR_REG, self.buf_dma & 0xffffffff)  # base address
        await self.hw_regs.write_dword(MQNIC_QUEUE_BASE_ADDR_REG+4, self.buf_dma >> 32)  # base address
        await self.hw_regs.write_dword(MQNIC_QUEUE_CPL_QUEUE_INDEX_REG, 0)  # completion queue index
        await self.hw_regs.write_dword(MQNIC_QUEUE_HEAD_PTR_REG, self.head_ptr & self.hw_ptr_mask)  # head pointer
        await self.hw_regs.write_dword(MQNIC_QUEUE_TAIL_PTR_REG, self.tail_ptr & self.hw_ptr_mask)  # tail pointer
        await self.hw_regs.write_dword(MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_queue_size | (self.log_desc_block_size << 8))  # active, log desc block size, log queue size

    async def activate(self, cpl_index):
        self.log.info("Activate TxRing %d (interface %d)", self.index, self.interface.index)

        self.cpl_index = cpl_index

        await self.hw_regs.write_dword(MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG, 0)  # active, log size
        await self.hw_regs.write_dword(MQNIC_QUEUE_CPL_QUEUE_INDEX_REG, cpl_index)  # completion queue index
        await self.hw_regs.write_dword(MQNIC_QUEUE_HEAD_PTR_REG, self.head_ptr & self.hw_ptr_mask)  # head pointer
        await self.hw_regs.write_dword(MQNIC_QUEUE_TAIL_PTR_REG, self.tail_ptr & self.hw_ptr_mask)  # tail pointer
        await self.hw_regs.write_dword(MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_queue_size | (self.log_desc_block_size << 8) | MQNIC_QUEUE_ACTIVE_MASK)  # active, log desc block size, log queue size

    async def deactivate(self):
        await self.hw_regs.write_dword(MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_queue_size | (self.log_desc_block_size << 8))  # active, log desc block size, log queue size

    def empty(self):
        return self.head_ptr == self.clean_tail_ptr

    def full(self):
        return self.head_ptr - self.clean_tail_ptr >= self.full_size

    async def read_tail_ptr(self):
        val = await self.hw_regs.read_dword(MQNIC_QUEUE_TAIL_PTR_REG)
        self.tail_ptr += (val - self.tail_ptr) & self.hw_ptr_mask

    async def write_head_ptr(self):
        await self.hw_regs.write_dword(MQNIC_QUEUE_HEAD_PTR_REG, self.head_ptr & self.hw_ptr_mask)

    def free_desc(self, index):
        pkt = self.tx_info[index]
        self.driver.free_pkt(pkt)
        self.tx_info[index] = None

    def free_buf(self):
        while not self.empty():
            index = self.clean_tail_ptr & self.size_mask
            self.free_desc(index)
            self.clean_tail_ptr += 1


class RxRing:
    def __init__(self, interface, size, stride, index, hw_regs):
        self.interface = interface
        self.log = interface.log
        self.driver = interface.driver
        self.rc = interface.driver.rc
        self.log_queue_size = size.bit_length() - 1
        self.log_desc_block_size = int(stride/MQNIC_DESC_SIZE).bit_length() - 1
        self.desc_block_size = 2**self.log_desc_block_size
        self.size = 2**self.log_queue_size
        self.size_mask = self.size-1
        self.full_size = self.size >> 1
        self.stride = stride
        self.index = index
        self.cpl_index = 0

        self.head_ptr = 0
        self.tail_ptr = 0
        self.clean_tail_ptr = 0

        self.packets = 0
        self.bytes = 0

        self.hw_ptr_mask = 0xffff
        self.hw_regs = hw_regs

    async def init(self):
        self.log.info("Init RxRing %d (interface %d)", self.index, self.interface.index)

        self.rx_info = [None]*self.size

        self.buf_size = self.size*self.stride
        self.buf_region = self.driver.pool.alloc_region(self.buf_size)
        self.buf_dma = self.buf_region.get_absolute_address(0)
        self.buf = self.buf_region.mem

        await self.hw_regs.write_dword(MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG, 0)  # active, log size
        await self.hw_regs.write_dword(MQNIC_QUEUE_BASE_ADDR_REG, self.buf_dma & 0xffffffff)  # base address
        await self.hw_regs.write_dword(MQNIC_QUEUE_BASE_ADDR_REG+4, self.buf_dma >> 32)  # base address
        await self.hw_regs.write_dword(MQNIC_QUEUE_CPL_QUEUE_INDEX_REG, 0)  # completion queue index
        await self.hw_regs.write_dword(MQNIC_QUEUE_HEAD_PTR_REG, self.head_ptr & self.hw_ptr_mask)  # head pointer
        await self.hw_regs.write_dword(MQNIC_QUEUE_TAIL_PTR_REG, self.tail_ptr & self.hw_ptr_mask)  # tail pointer
        await self.hw_regs.write_dword(MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_queue_size | (self.log_desc_block_size << 8))  # active, log desc block size, log queue size

    async def activate(self, cpl_index):
        self.log.info("Activate RxRing %d (interface %d)", self.index, self.interface.index)

        self.cpl_index = cpl_index

        await self.hw_regs.write_dword(MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG, 0)  # active, log size
        await self.hw_regs.write_dword(MQNIC_QUEUE_CPL_QUEUE_INDEX_REG, cpl_index)  # completion queue index
        await self.hw_regs.write_dword(MQNIC_QUEUE_HEAD_PTR_REG, self.head_ptr & self.hw_ptr_mask)  # head pointer
        await self.hw_regs.write_dword(MQNIC_QUEUE_TAIL_PTR_REG, self.tail_ptr & self.hw_ptr_mask)  # tail pointer
        await self.hw_regs.write_dword(MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_queue_size | (self.log_desc_block_size << 8) | MQNIC_QUEUE_ACTIVE_MASK)  # active, log desc block size, log queue size

        await self.refill_buffers()

    async def deactivate(self):
        await self.hw_regs.write_dword(MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_queue_size | (self.log_desc_block_size << 8))  # active, log desc block size, log queue size

    def empty(self):
        return self.head_ptr == self.clean_tail_ptr

    def full(self):
        return self.head_ptr - self.clean_tail_ptr >= self.full_size

    async def read_tail_ptr(self):
        val = await self.hw_regs.read_dword(MQNIC_QUEUE_TAIL_PTR_REG)
        self.tail_ptr += (val - self.tail_ptr) & self.hw_ptr_mask

    async def write_head_ptr(self):
        await self.hw_regs.write_dword(MQNIC_QUEUE_HEAD_PTR_REG, self.head_ptr & self.hw_ptr_mask)

    def free_desc(self, index):
        pkt = self.rx_info[index]
        self.driver.free_pkt(pkt)
        self.rx_info[index] = None

    def free_buf(self):
        while not self.empty():
            index = self.clean_tail_ptr & self.size_mask
            self.free_desc(index)
            self.clean_tail_ptr += 1

    def prepare_desc(self, index):
        pkt = self.driver.alloc_pkt()
        self.rx_info[index] = pkt

        length = pkt.size
        ptr = pkt.get_absolute_address(0)
        offset = 0

        # write descriptors
        for k in range(0, self.desc_block_size):
            seg = min(length-offset, 4096) if k < self.desc_block_size-1 else length-offset
            struct.pack_into("<LLQ", self.buf, index*self.stride+k*MQNIC_DESC_SIZE, 0, seg, ptr+offset if seg else 0)
            offset += seg

    async def refill_buffers(self):
        missing = self.size - (self.head_ptr - self.clean_tail_ptr)

        if missing < 8:
            return

        for k in range(missing):
            self.prepare_desc(self.head_ptr & self.size_mask)
            self.head_ptr += 1

        await self.write_head_ptr()


class Scheduler:
    def __init__(self, port, index, hw_regs):
        self.port = port
        self.log = port.log
        self.interface = port.interface
        self.driver = port.interface.driver
        self.rc = port.interface.driver.rc
        self.index = index
        self.hw_regs = hw_regs


class Port:
    def __init__(self, interface, index, hw_regs):
        self.interface = interface
        self.log = interface.log
        self.driver = interface.driver
        self.rc = interface.driver.rc
        self.index = index
        self.hw_regs = hw_regs

        self.port_id = None
        self.port_features = None
        self.port_mtu = 0
        self.sched_count = None
        self.sched_offset = None
        self.sched_stride = None
        self.sched_type = None

    async def init(self):
        # Read ID registers
        self.port_id = await self.hw_regs.read_dword(MQNIC_PORT_REG_PORT_ID)
        self.log.info("Port ID: 0x%08x", self.port_id)
        self.port_features = await self.hw_regs.read_dword(MQNIC_PORT_REG_PORT_FEATURES)
        self.log.info("Port features: 0x%08x", self.port_features)
        self.port_mtu = await self.hw_regs.read_dword(MQNIC_PORT_REG_PORT_MTU)
        self.log.info("Port MTU: %d", self.port_mtu)

        self.sched_count = await self.hw_regs.read_dword(MQNIC_PORT_REG_SCHED_COUNT)
        self.log.info("Scheduler count: %d", self.sched_count)
        self.sched_offset = await self.hw_regs.read_dword(MQNIC_PORT_REG_SCHED_OFFSET)
        self.log.info("Scheduler offset: 0x%08x", self.sched_offset)
        self.sched_stride = await self.hw_regs.read_dword(MQNIC_PORT_REG_SCHED_STRIDE)
        self.log.info("Scheduler stride: 0x%08x", self.sched_stride)
        self.sched_type = await self.hw_regs.read_dword(MQNIC_PORT_REG_SCHED_TYPE)
        self.log.info("Scheduler type: 0x%08x", self.sched_type)

        self.schedulers = []

        await self.set_mtu(min(self.port_mtu, 9214))

        for k in range(self.sched_count):
            p = Scheduler(self, k, self.hw_regs.parent.create_window(self.hw_regs.get_parent_address(0) + self.sched_offset + k*self.sched_stride, self.sched_stride))
            self.schedulers.append(p)

    async def set_mtu(self, mtu):
        await self.hw_regs.write_dword(MQNIC_PORT_REG_TX_MTU, mtu)
        await self.hw_regs.write_dword(MQNIC_PORT_REG_RX_MTU, mtu)


class Interface:
    def __init__(self, driver, index, hw_regs):
        self.driver = driver
        self.log = driver.log
        self.index = index
        self.hw_regs = hw_regs
        self.csr_hw_regs = hw_regs.create_window(driver.if_csr_offset, self.hw_regs.size-driver.if_csr_offset)
        self.port_up = False

        self.if_id = None
        self.event_queue_count = None
        self.event_queue_offset = None
        self.tx_queue_count = None
        self.tx_queue_offset = None
        self.tx_cpl_queue_count = None
        self.tx_cpl_queue_offset = None
        self.rx_queue_count = None
        self.rx_queue_offset = None
        self.rx_cpl_queue_count = None
        self.rx_cpl_queue_offset = None
        self.port_count = None
        self.port_offset = None
        self.port_stride = None

        self.interrupt_running = False
        self.interrupt_pending = 0

        self.pkt_rx_queue = deque()
        self.pkt_rx_sync = Event()

    async def init(self):
        # Read ID registers
        self.if_id = await self.csr_hw_regs.read_dword(MQNIC_IF_REG_IF_ID)
        self.log.info("IF ID: 0x%08x", self.if_id)
        self.if_features = await self.csr_hw_regs.read_dword(MQNIC_IF_REG_IF_FEATURES)
        self.log.info("IF features: 0x%08x", self.if_features)

        self.event_queue_count = await self.csr_hw_regs.read_dword(MQNIC_IF_REG_EVENT_QUEUE_COUNT)
        self.log.info("Event queue count: %d", self.event_queue_count)
        self.event_queue_offset = await self.csr_hw_regs.read_dword(MQNIC_IF_REG_EVENT_QUEUE_OFFSET)
        self.log.info("Event queue offset: 0x%08x", self.event_queue_offset)
        self.tx_queue_count = await self.csr_hw_regs.read_dword(MQNIC_IF_REG_TX_QUEUE_COUNT)
        self.log.info("TX queue count: %d", self.tx_queue_count)
        self.tx_queue_offset = await self.csr_hw_regs.read_dword(MQNIC_IF_REG_TX_QUEUE_OFFSET)
        self.log.info("TX queue offset: 0x%08x", self.tx_queue_offset)
        self.tx_cpl_queue_count = await self.csr_hw_regs.read_dword(MQNIC_IF_REG_TX_CPL_QUEUE_COUNT)
        self.log.info("TX completion queue count: %d", self.tx_cpl_queue_count)
        self.tx_cpl_queue_offset = await self.csr_hw_regs.read_dword(MQNIC_IF_REG_TX_CPL_QUEUE_OFFSET)
        self.log.info("TX completion queue offset: 0x%08x", self.tx_cpl_queue_offset)
        self.rx_queue_count = await self.csr_hw_regs.read_dword(MQNIC_IF_REG_RX_QUEUE_COUNT)
        self.log.info("RX queue count: %d", self.rx_queue_count)
        self.rx_queue_offset = await self.csr_hw_regs.read_dword(MQNIC_IF_REG_RX_QUEUE_OFFSET)
        self.log.info("RX queue offset: 0x%08x", self.rx_queue_offset)
        self.rx_cpl_queue_count = await self.csr_hw_regs.read_dword(MQNIC_IF_REG_RX_CPL_QUEUE_COUNT)
        self.log.info("RX completion queue count: %d", self.rx_cpl_queue_count)
        self.rx_cpl_queue_offset = await self.csr_hw_regs.read_dword(MQNIC_IF_REG_RX_CPL_QUEUE_OFFSET)
        self.log.info("RX completion queue offset: 0x%08x", self.rx_cpl_queue_offset)
        self.port_count = await self.csr_hw_regs.read_dword(MQNIC_IF_REG_PORT_COUNT)
        self.log.info("Port count: %d", self.port_count)
        self.port_offset = await self.csr_hw_regs.read_dword(MQNIC_IF_REG_PORT_OFFSET)
        self.log.info("Port offset: 0x%08x", self.port_offset)
        self.port_stride = await self.csr_hw_regs.read_dword(MQNIC_IF_REG_PORT_STRIDE)
        self.log.info("Port stride: 0x%08x", self.port_stride)

        self.event_queue_count = min(self.event_queue_count, MQNIC_MAX_EVENT_RINGS)
        self.tx_queue_count = min(self.tx_queue_count, MQNIC_MAX_TX_RINGS)
        self.tx_cpl_queue_count = min(self.tx_cpl_queue_count, MQNIC_MAX_TX_CPL_RINGS)
        self.rx_queue_count = min(self.rx_queue_count, MQNIC_MAX_RX_RINGS)
        self.rx_cpl_queue_count = min(self.rx_cpl_queue_count, MQNIC_MAX_RX_CPL_RINGS)

        self.event_queues = []
        self.tx_queues = []
        self.tx_cpl_queues = []
        self.rx_queues = []
        self.rx_cpl_queues = []
        self.ports = []

        for k in range(self.event_queue_count):
            q = EqRing(self, 1024, MQNIC_EVENT_SIZE, self.index,
                    self.hw_regs.create_window(self.event_queue_offset + k*MQNIC_EVENT_QUEUE_STRIDE, MQNIC_EVENT_QUEUE_STRIDE))
            await q.init()
            self.event_queues.append(q)

        for k in range(self.tx_queue_count):
            q = TxRing(self, 1024, MQNIC_DESC_SIZE*4, k,
                    self.hw_regs.create_window(self.tx_queue_offset + k*MQNIC_QUEUE_STRIDE, MQNIC_QUEUE_STRIDE))
            await q.init()
            self.tx_queues.append(q)

        for k in range(self.tx_cpl_queue_count):
            q = CqRing(self, 1024, MQNIC_CPL_SIZE, k,
                    self.hw_regs.create_window(self.tx_cpl_queue_offset + k*MQNIC_CPL_QUEUE_STRIDE, MQNIC_CPL_QUEUE_STRIDE))
            await q.init()
            self.tx_cpl_queues.append(q)

        for k in range(self.rx_queue_count):
            q = RxRing(self, 1024, MQNIC_DESC_SIZE*4, k,
                    self.hw_regs.create_window(self.rx_queue_offset + k*MQNIC_QUEUE_STRIDE, MQNIC_QUEUE_STRIDE))
            await q.init()
            self.rx_queues.append(q)

        for k in range(self.rx_cpl_queue_count):
            q = CqRing(self, 1024, MQNIC_CPL_SIZE, k,
                    self.hw_regs.create_window(self.rx_cpl_queue_offset + k*MQNIC_CPL_QUEUE_STRIDE, MQNIC_CPL_QUEUE_STRIDE))
            await q.init()
            self.rx_cpl_queues.append(q)

        for k in range(self.port_count):
            p = Port(self, k, self.hw_regs.create_window(self.port_offset + k*self.port_stride, self.port_stride))
            await p.init()
            self.ports.append(p)

        # wait for all writes to complete
        await self.hw_regs.read_dword(0)

    async def open(self):
        for q in self.event_queues:
            await q.activate(self.index)  # TODO?
            q.handler = None  # TODO
            await q.arm()

        for q in self.rx_cpl_queues:
            await q.activate(q.index % self.event_queue_count)
            q.ring_index = q.index
            q.handler = None  # TODO
            await q.arm()

        for q in self.rx_queues:
            await q.activate(q.index)

        for q in self.tx_cpl_queues:
            await q.activate(q.index % self.event_queue_count)
            q.ring_index = q.index
            q.handler = None  # TODO
            await q.arm()

        for q in self.tx_queues:
            await q.activate(q.index)

        # wait for all writes to complete
        await self.hw_regs.read_dword(0)

        self.port_up = True

    async def close(self):
        self.port_up = False

        for q in self.tx_queues:
            await q.deactivate()

        for q in self.tx_cpl_queues:
            await q.deactivate()

        for q in self.rx_queues:
            await q.deactivate()

        for q in self.rx_cpl_queues:
            await q.deactivate()

        for q in self.event_queues:
            await q.deactivate()

        # wait for all writes to complete
        await self.hw_regs.read_dword(0)

        for q in self.tx_queues:
            await q.free_buf()

        for q in self.rx_queues:
            await q.free_buf()

    async def interrupt(self):
        self.log.info("Interface interrupt (interface %d)", self.index)
        if self.interrupt_running:
            self.interrupt_pending += 1
            self.log.info("************************ interrupt was running")
            return
        self.interrupt_running = True
        for eq in self.event_queues:
            await eq.process()
            await eq.arm()
        self.interrupt_running = False
        self.log.info("Interface interrupt done (interface %d)", self.index)

        while self.interrupt_pending:
            self.interrupt_pending -= 1
            await self.interrupt()

    async def process_tx_cq(self, cq_ring):
        self.log.info("Process TX CQ %d (interface %d)", cq_ring.ring_index, self.index)

        ring = self.tx_queues[cq_ring.ring_index]

        if not self.port_up:
            return

        # process completion queue
        await cq_ring.read_head_ptr()

        cq_tail_ptr = cq_ring.tail_ptr
        cq_index = cq_tail_ptr & cq_ring.size_mask

        while (cq_ring.head_ptr != cq_tail_ptr):
            cpl_data = struct.unpack_from("<HHHxxQ", cq_ring.buf, cq_index*cq_ring.stride)
            ring_index = cpl_data[1]

            self.log.info("CPL data: %s", cpl_data)

            self.log.info("Ring index: %d", ring_index)

            ring.free_desc(ring_index)

            cq_tail_ptr += 1
            cq_index = cq_tail_ptr & cq_ring.size_mask

        cq_ring.tail_ptr = cq_tail_ptr
        await cq_ring.write_tail_ptr()

        # process ring
        await ring.read_tail_ptr()

        ring_clean_tail_ptr = ring.clean_tail_ptr
        ring_index = ring_clean_tail_ptr & ring.size_mask

        while (ring_clean_tail_ptr != ring.tail_ptr):
            if ring.tx_info[ring_index]:
                break

            ring_clean_tail_ptr += 1
            ring_index = ring_clean_tail_ptr & ring.size_mask

        ring.clean_tail_ptr = ring_clean_tail_ptr

    async def process_rx_cq(self, cq_ring):
        self.log.info("Process RX CQ %d (interface %d)", cq_ring.ring_index, self.index)

        ring = self.rx_queues[cq_ring.ring_index]

        if not self.port_up:
            return

        # process completion queue
        await cq_ring.read_head_ptr()

        cq_tail_ptr = cq_ring.tail_ptr
        cq_index = cq_tail_ptr & cq_ring.size_mask

        while (cq_ring.head_ptr != cq_tail_ptr):
            cpl_data = struct.unpack_from("<HHHxxLHH", cq_ring.buf, cq_index*cq_ring.stride)
            ring_index = cpl_data[1]

            self.log.info("CPL data: %s", cpl_data)

            self.log.info("Ring index: %d", ring_index)
            pkt = ring.rx_info[ring_index]

            length = cpl_data[2]

            skb = Packet()
            skb.data = pkt[:length]
            skb.timestamp_ns = cpl_data[3]
            skb.timestamp_s = cpl_data[4]
            skb.rx_checksum = cpl_data[5]

            self.log.info("Packet: %s", skb)

            self.pkt_rx_queue.append(skb)
            self.pkt_rx_sync.set()

            ring.free_desc(ring_index)

            cq_tail_ptr += 1
            cq_index = cq_tail_ptr & cq_ring.size_mask

        cq_ring.tail_ptr = cq_tail_ptr
        await cq_ring.write_tail_ptr()

        # process ring
        await ring.read_tail_ptr()

        ring_clean_tail_ptr = ring.clean_tail_ptr
        ring_index = ring_clean_tail_ptr & ring.size_mask

        while (ring_clean_tail_ptr != ring.tail_ptr):
            if ring.rx_info[ring_index]:
                break

            ring_clean_tail_ptr += 1
            ring_index = ring_clean_tail_ptr & ring.size_mask

        ring.clean_tail_ptr = ring_clean_tail_ptr

        # replenish buffers
        await ring.refill_buffers()

    async def start_xmit(self, skb, tx_ring=None, csum_start=None, csum_offset=None):
        if not self.port_up:
            return

        if isinstance(skb, Packet):
            data = skb.data
        else:
            data = skb

        data = data[:16384]  # TODO
        ring_index = tx_ring  # TODO!

        ring = self.tx_queues[ring_index]

        tail_ptr = ring.tail_ptr

        index = ring.head_ptr & ring.size_mask

        ring.packets += 1
        ring.bytes += len(data)

        pkt = self.driver.alloc_pkt()

        ring.tx_info[index] = pkt

        # put data in packet buffer
        pkt[10:len(data)+10] = data

        csum_cmd = 0

        if csum_start is not None and csum_offset is not None:
            csum_cmd = 0x8000 | (csum_offset << 8) | csum_start

        length = len(data)
        ptr = pkt.get_absolute_address(0)+10
        offset = 0

        # write descriptors
        seg = min(length-offset, 42) if ring.desc_block_size > 1 else length-offset
        struct.pack_into("<HHLQ", ring.buf, index*ring.stride, 0, csum_cmd, seg, ptr+offset if seg else 0)
        offset += seg
        for k in range(1, ring.desc_block_size):
            seg = min(length-offset, 4096) if k < ring.desc_block_size-1 else length-offset
            struct.pack_into("<4xLQ", ring.buf, index*ring.stride+k*MQNIC_DESC_SIZE, seg, ptr+offset if seg else 0)
            offset += seg

        ring.head_ptr += 1

        await ring.write_head_ptr()

    async def set_mtu(self, mtu):
        for p in self.ports:
            await p.set_mtu(mtu)

    async def recv(self):
        if not self.pkt_rx_queue:
            self.pkt_rx_sync.clear()
            await self.pkt_rx_sync.wait()
        return self.recv_nowait()

    def recv_nowait(self):
        if self.pkt_rx_queue:
            return self.pkt_rx_queue.popleft()
        return None

    async def wait(self):
        if not self.pkt_rx_queue:
            self.pkt_rx_sync.clear()
            await self.pkt_rx_sync.wait()


class Interrupt:
    def __init__(self, index, handler=None):
        self.index = index
        self.queue = Queue()
        self.handler = handler

        cocotb.start_soon(self._run())

    @classmethod
    def from_edge(cls, index, signal, handler=None):
        obj = cls(index, handler)
        obj.signal = signal
        cocotb.start_soon(obj._run_edge())
        return obj

    async def interrupt(self):
        self.queue.put_nowait(None)

    async def _run(self):
        while True:
            await self.queue.get()
            if self.handler:
                await self.handler(self.index)

    async def _run_edge(self):
        while True:
            await RisingEdge(self.signal)
            self.interrupt()


class Driver:
    def __init__(self):
        self.log = SimLog("cocotb.mqnic")

        self.rc = None
        self.dev_id = None
        self.rc_tree_ent = None

        self.pool = None

        self.hw_regs = None
        self.app_hw_regs = None
        self.ram_hw_regs = None

        self.irq_sig = None
        self.irq_list = []

        self.fw_id = None
        self.fw_ver = None
        self.board_id = None
        self.board_ver = None
        self.phc_count = None
        self.phc_offset = None
        self.phc_hw_addr = None
        self.if_count = None
        self.if_stride = None
        self.if_csr_offset = None

        self.initialized = False
        self.interrupt_running = False

        self.if_count = 1
        self.interfaces = []

        self.pkt_buf_size = 16384
        self.allocated_packets = []
        self.free_packets = deque()

    async def init_pcie_dev(self, rc, dev_id):
        assert not self.initialized
        self.initialized = True

        self.rc = rc
        self.dev_id = dev_id
        self.rc_tree_ent = self.rc.tree.find_child_dev(dev_id)

        self.pool = self.rc.mem_pool

        self.hw_regs = self.rc_tree_ent.bar_window[0]
        self.app_hw_regs = self.rc_tree_ent.bar_window[2]
        self.ram_hw_regs = self.rc_tree_ent.bar_window[4]

        # set up MSI
        for index in range(32):
            irq = Interrupt(index, self.interrupt_handler)
            self.rc.msi_register_callback(self.dev_id, irq.interrupt, index)
            self.irq_list.append(irq)

        await self.init_common()

    async def init_axi_dev(self, pool, hw_regs, app_hw_regs=None, irq=None):
        assert not self.initialized
        self.initialized = True

        self.pool = pool

        self.hw_regs = hw_regs
        self.app_hw_regs = app_hw_regs

        # set up edge-triggered interrupts
        if irq:
            for index in range(len(irq)):
                self.irq_list.append(Interrupt(index, self.interrupt_handler))
            cocotb.start_soon(self._run_edge_interrupts(irq))

        await self.init_common()

    async def init_common(self):
        self.log.info("Control BAR size: %d", self.hw_regs.size)
        if self.app_hw_regs:
            self.log.info("Application BAR size: %d", self.app_hw_regs.size)
        if self.ram_hw_regs:
            self.log.info("RAM BAR size: %d", self.ram_hw_regs.size)

        # Read ID registers
        self.fw_id = await self.hw_regs.read_dword(MQNIC_REG_FW_ID)
        self.log.info("FW ID: 0x%08x", self.fw_id)
        self.fw_ver = await self.hw_regs.read_dword(MQNIC_REG_FW_VER)
        self.log.info("FW version: %d.%d", self.fw_ver >> 16, self.fw_ver & 0xffff)
        self.board_id = await self.hw_regs.read_dword(MQNIC_REG_BOARD_ID)
        self.log.info("Board ID: 0x%08x", self.board_id)
        self.board_ver = await self.hw_regs.read_dword(MQNIC_REG_BOARD_VER)
        self.log.info("Board version: %d.%d", self.board_ver >> 16, self.board_ver & 0xffff)

        self.phc_count = await self.hw_regs.read_dword(MQNIC_REG_PHC_COUNT)
        self.log.info("PHC count: %d", self.phc_count)
        self.phc_offset = await self.hw_regs.read_dword(MQNIC_REG_PHC_OFFSET)
        self.log.info("PHC offset: 0x%08x", self.phc_offset)

        self.if_count = await self.hw_regs.read_dword(MQNIC_REG_IF_COUNT)
        self.log.info("IF count: %d", self.if_count)
        self.if_stride = await self.hw_regs.read_dword(MQNIC_REG_IF_STRIDE)
        self.log.info("IF stride: 0x%08x", self.if_stride)
        self.if_csr_offset = await self.hw_regs.read_dword(MQNIC_REG_IF_CSR_OFFSET)
        self.log.info("IF CSR offset: 0x%08x", self.if_csr_offset)

        self.interfaces = []

        for k in range(self.if_count):
            i = Interface(self, k, self.hw_regs.create_window(k*self.if_stride, self.if_stride))
            await i.init()
            self.interfaces.append(i)

    async def _run_edge_interrupts(self, signal):
        last_val = 0
        count = len(signal)
        while True:
            await Edge(signal)
            val = signal.value.integer
            edge = val & ~last_val
            for index in (x for x in range(count) if edge & (1 << x)):
                await self.irq_list[index].interrupt()

    async def interrupt_handler(self, index):
        self.log.info("Interrupt handler start (IRQ %d)", index)
        for i in self.interfaces:
            for eq in i.event_queues:
                if eq.interrupt_index == index:
                    await eq.process()
                    await eq.arm()
        self.log.info("Interrupt handler end (IRQ %d)", index)

    def alloc_pkt(self):
        if self.free_packets:
            return self.free_packets.popleft()

        pkt = self.pool.alloc_region(self.pkt_buf_size)
        self.allocated_packets.append(pkt)
        return pkt

    def free_pkt(self, pkt):
        assert pkt is not None
        assert pkt in self.allocated_packets
        self.free_packets.append(pkt)
