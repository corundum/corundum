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

import datetime
from collections import deque

import cocotb
from cocotb.log import SimLog
from cocotb.queue import Queue
from cocotb.triggers import Event, Edge, RisingEdge

from cocotbext.axi import Window

import struct

MQNIC_MAX_EVENT_RINGS   = 1
MQNIC_MAX_TX_RINGS      = 32
MQNIC_MAX_TX_CPL_RINGS  = 32
MQNIC_MAX_RX_RINGS      = 8
MQNIC_MAX_RX_CPL_RINGS  = 8

# Register blocks
MQNIC_RB_REG_TYPE      = 0x00
MQNIC_RB_REG_VER       = 0x04
MQNIC_RB_REG_NEXT_PTR  = 0x08

MQNIC_RB_FW_ID_TYPE            = 0xFFFFFFFF
MQNIC_RB_FW_ID_VER             = 0x00000100
MQNIC_RB_FW_ID_REG_FPGA_ID     = 0x0C
MQNIC_RB_FW_ID_REG_FW_ID       = 0x10
MQNIC_RB_FW_ID_REG_FW_VER      = 0x14
MQNIC_RB_FW_ID_REG_BOARD_ID    = 0x18
MQNIC_RB_FW_ID_REG_BOARD_VER   = 0x1C
MQNIC_RB_FW_ID_REG_BUILD_DATE  = 0x20
MQNIC_RB_FW_ID_REG_GIT_HASH    = 0x24
MQNIC_RB_FW_ID_REG_REL_INFO    = 0x28

MQNIC_RB_GPIO_TYPE          = 0x0000C100
MQNIC_RB_GPIO_VER           = 0x00000100
MQNIC_RB_GPIO_REG_GPIO_IN   = 0x0C
MQNIC_RB_GPIO_REG_GPIO_OUT  = 0x10

MQNIC_RB_I2C_TYPE      = 0x0000C110
MQNIC_RB_I2C_VER       = 0x00000100
MQNIC_RB_I2C_REG_CTRL  = 0x0C

MQNIC_RB_SPI_FLASH_TYPE        = 0x0000C120
MQNIC_RB_SPI_FLASH_VER         = 0x00000100
MQNIC_RB_SPI_FLASH_REG_FORMAT  = 0x0C
MQNIC_RB_SPI_FLASH_REG_CTRL_0  = 0x10
MQNIC_RB_SPI_FLASH_REG_CTRL_1  = 0x14

MQNIC_RB_BPI_FLASH_TYPE        = 0x0000C121
MQNIC_RB_BPI_FLASH_VER         = 0x00000100
MQNIC_RB_BPI_FLASH_REG_FORMAT  = 0x0C
MQNIC_RB_BPI_FLASH_REG_ADDR    = 0x10
MQNIC_RB_BPI_FLASH_REG_DATA    = 0x14
MQNIC_RB_BPI_FLASH_REG_CTRL    = 0x18

MQNIC_RB_ALVEO_BMC_TYPE      = 0x0000C140
MQNIC_RB_ALVEO_BMC_VER       = 0x00000100
MQNIC_RB_ALVEO_BMC_REG_ADDR  = 0x0C
MQNIC_RB_ALVEO_BMC_REG_DATA  = 0x10

MQNIC_RB_GECKO_BMC_TYPE        = 0x0000C141
MQNIC_RB_GECKO_BMC_VER         = 0x00000100
MQNIC_RB_GECKO_BMC_REG_STATUS  = 0x0C
MQNIC_RB_GECKO_BMC_REG_DATA    = 0x10
MQNIC_RB_GECKO_BMC_REG_CMD     = 0x14

MQNIC_RB_STATS_TYPE        = 0x0000C006
MQNIC_RB_STATS_VER         = 0x00000100
MQNIC_RB_STATS_REG_OFFSET  = 0x0C
MQNIC_RB_STATS_REG_COUNT   = 0x10
MQNIC_RB_STATS_REG_STRIDE  = 0x14
MQNIC_RB_STATS_REG_FLAGS   = 0x18

MQNIC_RB_IRQ_TYPE        = 0x0000C007
MQNIC_RB_IRQ_VER         = 0x00000100

MQNIC_RB_CLK_INFO_TYPE         = 0x0000C008
MQNIC_RB_CLK_INFO_VER          = 0x00000100
MQNIC_RB_CLK_INFO_COUNT        = 0x0C
MQNIC_RB_CLK_INFO_REF_NOM_PER  = 0x10
MQNIC_RB_CLK_INFO_CLK_NOM_PER  = 0x18
MQNIC_RB_CLK_INFO_CLK_FREQ     = 0x1C
MQNIC_RB_CLK_INFO_FREQ_BASE    = 0x20

MQNIC_RB_PHC_TYPE               = 0x0000C080
MQNIC_RB_PHC_VER                = 0x00000100
MQNIC_RB_PHC_REG_CTRL           = 0x0C
MQNIC_RB_PHC_REG_CUR_FNS        = 0x10
MQNIC_RB_PHC_REG_CUR_NS         = 0x14
MQNIC_RB_PHC_REG_CUR_SEC_L      = 0x18
MQNIC_RB_PHC_REG_CUR_SEC_H      = 0x1C
MQNIC_RB_PHC_REG_GET_FNS        = 0x20
MQNIC_RB_PHC_REG_GET_NS         = 0x24
MQNIC_RB_PHC_REG_GET_SEC_L      = 0x28
MQNIC_RB_PHC_REG_GET_SEC_H      = 0x2C
MQNIC_RB_PHC_REG_SET_FNS        = 0x30
MQNIC_RB_PHC_REG_SET_NS         = 0x34
MQNIC_RB_PHC_REG_SET_SEC_L      = 0x38
MQNIC_RB_PHC_REG_SET_SEC_H      = 0x3C
MQNIC_RB_PHC_REG_PERIOD_FNS     = 0x40
MQNIC_RB_PHC_REG_PERIOD_NS      = 0x44
MQNIC_RB_PHC_REG_NOM_PERIOD_FNS = 0x48
MQNIC_RB_PHC_REG_NOM_PERIOD_NS  = 0x4C
MQNIC_RB_PHC_REG_ADJ_FNS        = 0x50
MQNIC_RB_PHC_REG_ADJ_NS         = 0x54
MQNIC_RB_PHC_REG_ADJ_COUNT      = 0x58
MQNIC_RB_PHC_REG_ADJ_ACTIVE     = 0x5C

MQNIC_RB_PHC_PEROUT_TYPE              = 0x0000C081
MQNIC_RB_PHC_PEROUT_VER               = 0x00000100
MQNIC_RB_PHC_PEROUT_REG_CTRL          = 0x0C
MQNIC_RB_PHC_PEROUT_REG_START_FNS     = 0x10
MQNIC_RB_PHC_PEROUT_REG_START_NS      = 0x14
MQNIC_RB_PHC_PEROUT_REG_START_SEC_L   = 0x18
MQNIC_RB_PHC_PEROUT_REG_START_SEC_H   = 0x1C
MQNIC_RB_PHC_PEROUT_REG_PERIOD_FNS    = 0x20
MQNIC_RB_PHC_PEROUT_REG_PERIOD_NS     = 0x24
MQNIC_RB_PHC_PEROUT_REG_PERIOD_SEC_L  = 0x28
MQNIC_RB_PHC_PEROUT_REG_PERIOD_SEC_H  = 0x2C
MQNIC_RB_PHC_PEROUT_REG_WIDTH_FNS     = 0x30
MQNIC_RB_PHC_PEROUT_REG_WIDTH_NS      = 0x34
MQNIC_RB_PHC_PEROUT_REG_WIDTH_SEC_L   = 0x38
MQNIC_RB_PHC_PEROUT_REG_WIDTH_SEC_H   = 0x3C

MQNIC_RB_IF_TYPE            = 0x0000C000
MQNIC_RB_IF_VER             = 0x00000100
MQNIC_RB_IF_REG_OFFSET      = 0x0C
MQNIC_RB_IF_REG_COUNT       = 0x10
MQNIC_RB_IF_REG_STRIDE      = 0x14
MQNIC_RB_IF_REG_CSR_OFFSET  = 0x18

MQNIC_RB_IF_CTRL_TYPE            = 0x0000C001
MQNIC_RB_IF_CTRL_VER             = 0x00000400
MQNIC_RB_IF_CTRL_REG_FEATURES    = 0x0C
MQNIC_RB_IF_CTRL_REG_PORT_COUNT  = 0x10
MQNIC_RB_IF_CTRL_REG_SCHED_COUNT = 0x14
MQNIC_RB_IF_CTRL_REG_MAX_TX_MTU  = 0x20
MQNIC_RB_IF_CTRL_REG_MAX_RX_MTU  = 0x24
MQNIC_RB_IF_CTRL_REG_TX_MTU      = 0x28
MQNIC_RB_IF_CTRL_REG_RX_MTU      = 0x2C

MQNIC_IF_FEATURE_RSS      = (1 << 0)
MQNIC_IF_FEATURE_PTP_TS   = (1 << 4)
MQNIC_IF_FEATURE_TX_CSUM  = (1 << 8)
MQNIC_IF_FEATURE_RX_CSUM  = (1 << 9)
MQNIC_IF_FEATURE_RX_HASH  = (1 << 10)

MQNIC_RB_RX_QUEUE_MAP_TYPE             = 0x0000C090
MQNIC_RB_RX_QUEUE_MAP_VER              = 0x00000100
MQNIC_RB_RX_QUEUE_MAP_REG_PORTS        = 0x0C
MQNIC_RB_RX_QUEUE_MAP_CH_OFFSET        = 0x10
MQNIC_RB_RX_QUEUE_MAP_CH_STRIDE        = 0x10
MQNIC_RB_RX_QUEUE_MAP_CH_REG_OFFSET    = 0x00
MQNIC_RB_RX_QUEUE_MAP_CH_REG_RSS_MASK  = 0x04
MQNIC_RB_RX_QUEUE_MAP_CH_REG_APP_MASK  = 0x08

MQNIC_RB_EVENT_QM_TYPE        = 0x0000C010
MQNIC_RB_EVENT_QM_VER         = 0x00000100
MQNIC_RB_EVENT_QM_REG_OFFSET  = 0x0C
MQNIC_RB_EVENT_QM_REG_COUNT   = 0x10
MQNIC_RB_EVENT_QM_REG_STRIDE  = 0x14

MQNIC_RB_TX_QM_TYPE        = 0x0000C020
MQNIC_RB_TX_QM_VER         = 0x00000100
MQNIC_RB_TX_QM_REG_OFFSET  = 0x0C
MQNIC_RB_TX_QM_REG_COUNT   = 0x10
MQNIC_RB_TX_QM_REG_STRIDE  = 0x14

MQNIC_RB_TX_CQM_TYPE        = 0x0000C030
MQNIC_RB_TX_CQM_VER         = 0x00000100
MQNIC_RB_TX_CQM_REG_OFFSET  = 0x0C
MQNIC_RB_TX_CQM_REG_COUNT   = 0x10
MQNIC_RB_TX_CQM_REG_STRIDE  = 0x14

MQNIC_RB_RX_QM_TYPE        = 0x0000C021
MQNIC_RB_RX_QM_VER         = 0x00000100
MQNIC_RB_RX_QM_REG_OFFSET  = 0x0C
MQNIC_RB_RX_QM_REG_COUNT   = 0x10
MQNIC_RB_RX_QM_REG_STRIDE  = 0x14

MQNIC_RB_RX_CQM_TYPE        = 0x0000C031
MQNIC_RB_RX_CQM_VER         = 0x00000100
MQNIC_RB_RX_CQM_REG_OFFSET  = 0x0C
MQNIC_RB_RX_CQM_REG_COUNT   = 0x10
MQNIC_RB_RX_CQM_REG_STRIDE  = 0x14

MQNIC_RB_PORT_TYPE        = 0x0000C002
MQNIC_RB_PORT_VER         = 0x00000200
MQNIC_RB_PORT_REG_OFFSET  = 0x0C

MQNIC_RB_PORT_CTRL_TYPE           = 0x0000C003
MQNIC_RB_PORT_CTRL_VER            = 0x00000200
MQNIC_RB_PORT_CTRL_REG_FEATURES   = 0x0C
MQNIC_RB_PORT_CTRL_REG_TX_STATUS  = 0x10
MQNIC_RB_PORT_CTRL_REG_RX_STATUS  = 0x14

MQNIC_RB_SCHED_BLOCK_TYPE        = 0x0000C004
MQNIC_RB_SCHED_BLOCK_VER         = 0x00000300
MQNIC_RB_SCHED_BLOCK_REG_OFFSET  = 0x0C

MQNIC_RB_SCHED_RR_TYPE           = 0x0000C040
MQNIC_RB_SCHED_RR_VER            = 0x00000100
MQNIC_RB_SCHED_RR_REG_OFFSET     = 0x0C
MQNIC_RB_SCHED_RR_REG_CH_COUNT   = 0x10
MQNIC_RB_SCHED_RR_REG_CH_STRIDE  = 0x14
MQNIC_RB_SCHED_RR_REG_CTRL       = 0x18
MQNIC_RB_SCHED_RR_REG_DEST       = 0x1C

MQNIC_RB_SCHED_CTRL_TDMA_TYPE           = 0x0000C050
MQNIC_RB_SCHED_CTRL_TDMA_VER            = 0x00000100
MQNIC_RB_SCHED_CTRL_TDMA_REG_OFFSET     = 0x0C
MQNIC_RB_SCHED_CTRL_TDMA_REG_CH_COUNT   = 0x10
MQNIC_RB_SCHED_CTRL_TDMA_REG_CH_STRIDE  = 0x14
MQNIC_RB_SCHED_CTRL_TDMA_REG_CTRL       = 0x18
MQNIC_RB_SCHED_CTRL_TDMA_REG_TS_COUNT   = 0x1C

MQNIC_RB_TDMA_SCH_TYPE                     = 0x0000C060
MQNIC_RB_TDMA_SCH_VER                      = 0x00000100
MQNIC_RB_TDMA_SCH_REG_TS_COUNT             = 0x0C
MQNIC_RB_TDMA_SCH_REG_CTRL                 = 0x10
MQNIC_RB_TDMA_SCH_REG_STATUS               = 0x14
MQNIC_RB_TDMA_SCH_REG_SCH_START_FNS        = 0x20
MQNIC_RB_TDMA_SCH_REG_SCH_START_NS         = 0x24
MQNIC_RB_TDMA_SCH_REG_SCH_START_SEC_L      = 0x28
MQNIC_RB_TDMA_SCH_REG_SCH_START_SEC_H      = 0x2C
MQNIC_RB_TDMA_SCH_REG_SCH_PERIOD_FNS       = 0x30
MQNIC_RB_TDMA_SCH_REG_SCH_PERIOD_NS        = 0x34
MQNIC_RB_TDMA_SCH_REG_SCH_PERIOD_SEC_L     = 0x38
MQNIC_RB_TDMA_SCH_REG_SCH_PERIOD_SEC_H     = 0x3C
MQNIC_RB_TDMA_SCH_REG_TS_PERIOD_FNS        = 0x40
MQNIC_RB_TDMA_SCH_REG_TS_PERIOD_NS         = 0x44
MQNIC_RB_TDMA_SCH_REG_TS_PERIOD_SEC_L      = 0x48
MQNIC_RB_TDMA_SCH_REG_TS_PERIOD_SEC_H      = 0x4C
MQNIC_RB_TDMA_SCH_REG_ACTIVE_PERIOD_FNS    = 0x50
MQNIC_RB_TDMA_SCH_REG_ACTIVE_PERIOD_NS     = 0x54
MQNIC_RB_TDMA_SCH_REG_ACTIVE_PERIOD_SEC_L  = 0x58
MQNIC_RB_TDMA_SCH_REG_ACTIVE_PERIOD_SEC_H  = 0x5C

MQNIC_RB_APP_INFO_TYPE    = 0x0000C005
MQNIC_RB_APP_INFO_VER     = 0x00000200
MQNIC_RB_APP_INFO_REG_ID  = 0x0C

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


class RegBlock(Window):
    def __init__(self, parent, offset, size, base=0, **kwargs):
        super().__init__(parent, offset, size, base, **kwargs)
        self._offset = offset
        self.type = 0
        self.version = 0


class RegBlockList:
    def __init__(self):
        self.blocks = []

    async def enumerate_reg_blocks(self, window, offset=0):
        while True:
            rb_type = await window.read_dword(offset+MQNIC_RB_REG_TYPE)
            rb_version = await window.read_dword(offset+MQNIC_RB_REG_VER)
            rb = window.create_window(offset, window_type=RegBlock)
            rb.type = rb_type
            rb.version = rb_version
            print(f"Block ID {rb_type:#010x} version {rb_version:#010x} at offset {offset:#010x}")
            self.blocks.append(rb)
            offset = await window.read_dword(offset+MQNIC_RB_REG_NEXT_PTR)
            if offset == 0:
                return
            assert offset & 0x3 == 0, "Register block not aligned"
            for block in self.blocks:
                assert block.offset != offset, "Register blocks form a loop"

    def find(self, rb_type, version=None, index=0):
        for block in self.blocks:
            if block.type == rb_type and (not version or block.version == version):
                if index <= 0:
                    return block
                else:
                    index -= 1
        return None

    def __getitem__(self, key):
        return self.blocks[key]

    def __len__(self):
        return len(self.blocks)


class Packet:
    def __init__(self, data=b''):
        self.data = data
        self.queue = None
        self.timestamp_s = None
        self.timestamp_ns = None
        self.rx_checksum = None

    def __repr__(self):
        return (
            f'{type(self).__name__}(data={self.data}, '
            f'queue={self.queue}, '
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

        self.clean_event = Event()

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


class BaseScheduler:
    def __init__(self, port, index, rb):
        self.port = port
        self.log = port.log
        self.interface = port.interface
        self.driver = port.interface.driver
        self.index = index
        self.rb = rb
        self.hw_regs = None

    async def init(self):
        pass


class SchedulerRoundRobin(BaseScheduler):
    def __init__(self, port, index, rb):
        super().__init__(port, index, rb)

    async def init(self):
        offset = await self.rb.read_dword(MQNIC_RB_SCHED_RR_REG_OFFSET)
        self.hw_regs = self.rb.parent.create_window(offset)


class SchedulerControlTdma(BaseScheduler):
    def __init__(self, port, index, rb):
        super().__init__(port, index, rb)

    async def init(self):
        offset = await self.rb.read_dword(MQNIC_RB_SCHED_CTRL_TDMA_REG_OFFSET)
        self.hw_regs = self.rb.parent.create_window(offset)


class SchedulerBlock:
    def __init__(self, interface, index, rb):
        self.interface = interface
        self.log = interface.log
        self.driver = interface.driver
        self.index = index

        self.block_rb = rb
        self.reg_blocks = RegBlockList()

        self.sched_count = None

        self.schedulers = []

    async def init(self):
        # Read ID registers

        offset = await self.block_rb.read_dword(MQNIC_RB_SCHED_BLOCK_REG_OFFSET)
        await self.reg_blocks.enumerate_reg_blocks(self.block_rb.parent, offset)

        self.schedulers = []

        self.sched_count = 0
        for rb in self.reg_blocks:
            if rb.type == MQNIC_RB_SCHED_RR_TYPE and rb.version == MQNIC_RB_SCHED_RR_VER:
                s = SchedulerRoundRobin(self, self.sched_count, rb)
                await s.init()
                self.schedulers.append(s)

                self.sched_count += 1
            elif rb.type == MQNIC_RB_SCHED_CTRL_TDMA_TYPE and rb.version == MQNIC_RB_SCHED_CTRL_TDMA_VER:
                s = SchedulerControlTdma(self, self.sched_count, rb)
                await s.init()
                self.schedulers.append(s)

                self.sched_count += 1

        self.log.info("Scheduler count: %d", self.sched_count)


class Port:
    def __init__(self, interface, index, rb):
        self.interface = interface
        self.log = interface.log
        self.driver = interface.driver
        self.index = index

        self.port_rb = rb
        self.reg_blocks = RegBlockList()
        self.port_ctrl_rb = None

        self.port_features = None

    async def init(self):
        # Read ID registers

        offset = await self.port_rb.read_dword(MQNIC_RB_PORT_REG_OFFSET)
        await self.reg_blocks.enumerate_reg_blocks(self.port_rb.parent, offset)

        self.port_ctrl_rb = self.reg_blocks.find(MQNIC_RB_PORT_CTRL_TYPE, MQNIC_RB_PORT_CTRL_VER)

        self.port_features = await self.port_ctrl_rb.read_dword(MQNIC_RB_PORT_CTRL_REG_FEATURES)

        self.log.info("Port features: 0x%08x", self.port_features)

    async def get_tx_status(self, port):
        return await self.port_ctrl_rb.read_dword(MQNIC_RB_PORT_CTRL_REG_TX_STATUS)

    async def get_rx_status(self, port):
        return await self.port_ctrl_rb.read_dword(MQNIC_RB_PORT_CTRL_REG_RX_STATUS)


class Interface:
    def __init__(self, driver, index, hw_regs):
        self.driver = driver
        self.log = driver.log
        self.index = index
        self.hw_regs = hw_regs
        self.csr_hw_regs = hw_regs.create_window(driver.if_csr_offset)
        self.port_up = False

        self.reg_blocks = RegBlockList()
        self.if_ctrl_rb = None
        self.event_queue_rb = None
        self.tx_queue_rb = None
        self.tx_cpl_queue_rb = None
        self.rx_queue_rb = None
        self.rx_cpl_queue_rb = None
        self.rx_queue_map_rb = None

        self.if_features = None

        self.max_tx_mtu = 0
        self.max_rx_mtu = 0

        self.event_queue_offset = None
        self.event_queue_count = None
        self.event_queue_stride = None
        self.tx_queue_offset = None
        self.tx_queue_count = None
        self.tx_queue_stride = None
        self.tx_cpl_queue_offset = None
        self.tx_cpl_queue_count = None
        self.tx_cpl_queue_stride = None
        self.rx_queue_offset = None
        self.rx_queue_count = None
        self.rx_queue_stride = None
        self.rx_cpl_queue_offset = None
        self.rx_cpl_queue_count = None
        self.rx_cpl_queue_stride = None

        self.port_count = None
        self.sched_block_count = None

        self.event_queues = []

        self.tx_queues = []
        self.tx_cpl_queues = []
        self.rx_queues = []
        self.rx_cpl_queues = []
        self.ports = []
        self.sched_blocks = []

        self.interrupt_running = False
        self.interrupt_pending = 0

        self.pkt_rx_queue = deque()
        self.pkt_rx_sync = Event()

    async def init(self):
        # Read ID registers

        # Enumerate registers
        await self.reg_blocks.enumerate_reg_blocks(self.hw_regs, self.driver.if_csr_offset)

        self.if_ctrl_rb = self.reg_blocks.find(MQNIC_RB_IF_CTRL_TYPE, MQNIC_RB_IF_CTRL_VER)

        self.if_features = await self.if_ctrl_rb.read_dword(MQNIC_RB_IF_CTRL_REG_FEATURES)
        self.port_count = await self.if_ctrl_rb.read_dword(MQNIC_RB_IF_CTRL_REG_PORT_COUNT)
        self.sched_block_count = await self.if_ctrl_rb.read_dword(MQNIC_RB_IF_CTRL_REG_SCHED_COUNT)
        self.max_tx_mtu = await self.if_ctrl_rb.read_dword(MQNIC_RB_IF_CTRL_REG_MAX_TX_MTU)
        self.max_rx_mtu = await self.if_ctrl_rb.read_dword(MQNIC_RB_IF_CTRL_REG_MAX_RX_MTU)

        self.log.info("IF features: 0x%08x", self.if_features)
        self.log.info("Port count: %d", self.port_count)
        self.log.info("Scheduler block count: %d", self.sched_block_count)
        self.log.info("Max TX MTU: %d", self.max_tx_mtu)
        self.log.info("Max RX MTU: %d", self.max_rx_mtu)

        await self.set_mtu(min(self.max_tx_mtu, self.max_rx_mtu, 9214))

        self.event_queue_rb = self.reg_blocks.find(MQNIC_RB_EVENT_QM_TYPE, MQNIC_RB_EVENT_QM_VER)

        self.event_queue_offset = await self.event_queue_rb.read_dword(MQNIC_RB_EVENT_QM_REG_OFFSET)
        self.event_queue_count = await self.event_queue_rb.read_dword(MQNIC_RB_EVENT_QM_REG_COUNT)
        self.event_queue_stride = await self.event_queue_rb.read_dword(MQNIC_RB_EVENT_QM_REG_STRIDE)

        self.log.info("Event queue offset: 0x%08x", self.event_queue_offset)
        self.log.info("Event queue count: %d", self.event_queue_count)
        self.log.info("Event queue stride: 0x%08x", self.event_queue_stride)

        self.event_queue_count = min(self.event_queue_count, MQNIC_MAX_EVENT_RINGS)

        self.tx_queue_rb = self.reg_blocks.find(MQNIC_RB_TX_QM_TYPE, MQNIC_RB_TX_QM_VER)

        self.tx_queue_offset = await self.tx_queue_rb.read_dword(MQNIC_RB_TX_QM_REG_OFFSET)
        self.tx_queue_count = await self.tx_queue_rb.read_dword(MQNIC_RB_TX_QM_REG_COUNT)
        self.tx_queue_stride = await self.tx_queue_rb.read_dword(MQNIC_RB_TX_QM_REG_STRIDE)

        self.log.info("TX queue offset: 0x%08x", self.tx_queue_offset)
        self.log.info("TX queue count: %d", self.tx_queue_count)
        self.log.info("TX queue stride: 0x%08x", self.tx_queue_stride)

        self.tx_queue_count = min(self.tx_queue_count, MQNIC_MAX_TX_RINGS)

        self.tx_cpl_queue_rb = self.reg_blocks.find(MQNIC_RB_TX_CQM_TYPE, MQNIC_RB_TX_CQM_VER)

        self.tx_cpl_queue_offset = await self.tx_cpl_queue_rb.read_dword(MQNIC_RB_TX_CQM_REG_OFFSET)
        self.tx_cpl_queue_count = await self.tx_cpl_queue_rb.read_dword(MQNIC_RB_TX_CQM_REG_COUNT)
        self.tx_cpl_queue_stride = await self.tx_cpl_queue_rb.read_dword(MQNIC_RB_TX_CQM_REG_STRIDE)

        self.log.info("TX completion queue offset: 0x%08x", self.tx_cpl_queue_offset)
        self.log.info("TX completion queue count: %d", self.tx_cpl_queue_count)
        self.log.info("TX completion queue stride: 0x%08x", self.tx_cpl_queue_stride)

        self.tx_cpl_queue_count = min(self.tx_cpl_queue_count, MQNIC_MAX_TX_CPL_RINGS)

        self.rx_queue_rb = self.reg_blocks.find(MQNIC_RB_RX_QM_TYPE, MQNIC_RB_RX_QM_VER)

        self.rx_queue_offset = await self.rx_queue_rb.read_dword(MQNIC_RB_RX_QM_REG_OFFSET)
        self.rx_queue_count = await self.rx_queue_rb.read_dword(MQNIC_RB_RX_QM_REG_COUNT)
        self.rx_queue_stride = await self.rx_queue_rb.read_dword(MQNIC_RB_RX_QM_REG_STRIDE)

        self.log.info("RX queue offset: 0x%08x", self.rx_queue_offset)
        self.log.info("RX queue count: %d", self.rx_queue_count)
        self.log.info("RX queue stride: 0x%08x", self.rx_queue_stride)

        self.rx_queue_count = min(self.rx_queue_count, MQNIC_MAX_RX_RINGS)

        self.rx_cpl_queue_rb = self.reg_blocks.find(MQNIC_RB_RX_CQM_TYPE, MQNIC_RB_RX_CQM_VER)

        self.rx_cpl_queue_offset = await self.rx_cpl_queue_rb.read_dword(MQNIC_RB_RX_CQM_REG_OFFSET)
        self.rx_cpl_queue_count = await self.rx_cpl_queue_rb.read_dword(MQNIC_RB_RX_CQM_REG_COUNT)
        self.rx_cpl_queue_stride = await self.rx_cpl_queue_rb.read_dword(MQNIC_RB_RX_CQM_REG_STRIDE)

        self.log.info("RX completion queue offset: 0x%08x", self.rx_cpl_queue_offset)
        self.log.info("RX completion queue count: %d", self.rx_cpl_queue_count)
        self.log.info("RX completion queue stride: 0x%08x", self.rx_cpl_queue_stride)

        self.rx_cpl_queue_count = min(self.rx_cpl_queue_count, MQNIC_MAX_RX_CPL_RINGS)

        self.rx_queue_map_rb = self.reg_blocks.find(MQNIC_RB_RX_QUEUE_MAP_TYPE, MQNIC_RB_RX_QUEUE_MAP_VER)

        for k in range(self.port_count):
            await self.set_rx_queue_map_offset(k, 0)
            await self.set_rx_queue_map_rss_mask(k, 0)
            await self.set_rx_queue_map_app_mask(k, 0)

        self.event_queues = []

        self.tx_queues = []
        self.tx_cpl_queues = []
        self.rx_queues = []
        self.rx_cpl_queues = []
        self.ports = []
        self.sched_blocks = []

        for k in range(self.event_queue_count):
            q = EqRing(self, 1024, MQNIC_EVENT_SIZE, self.index,
                    self.hw_regs.create_window(self.event_queue_offset + k*self.event_queue_stride, self.event_queue_stride))
            await q.init()
            self.event_queues.append(q)

        for k in range(self.tx_queue_count):
            q = TxRing(self, 1024, MQNIC_DESC_SIZE*4, k,
                    self.hw_regs.create_window(self.tx_queue_offset + k*self.tx_queue_stride, self.tx_queue_stride))
            await q.init()
            self.tx_queues.append(q)

        for k in range(self.tx_cpl_queue_count):
            q = CqRing(self, 1024, MQNIC_CPL_SIZE, k,
                    self.hw_regs.create_window(self.tx_cpl_queue_offset + k*self.tx_cpl_queue_stride, self.tx_cpl_queue_stride))
            await q.init()
            self.tx_cpl_queues.append(q)

        for k in range(self.rx_queue_count):
            q = RxRing(self, 1024, MQNIC_DESC_SIZE*4, k,
                    self.hw_regs.create_window(self.rx_queue_offset + k*self.rx_queue_stride, self.rx_queue_stride))
            await q.init()
            self.rx_queues.append(q)

        for k in range(self.rx_cpl_queue_count):
            q = CqRing(self, 1024, MQNIC_CPL_SIZE, k,
                    self.hw_regs.create_window(self.rx_cpl_queue_offset + k*self.rx_cpl_queue_stride, self.rx_cpl_queue_stride))
            await q.init()
            self.rx_cpl_queues.append(q)

        for k in range(self.port_count):
            rb = self.reg_blocks.find(MQNIC_RB_PORT_TYPE, MQNIC_RB_PORT_VER, index=k)

            p = Port(self, k, rb)
            await p.init()
            self.ports.append(p)

        for k in range(self.sched_block_count):
            rb = self.reg_blocks.find(MQNIC_RB_SCHED_BLOCK_TYPE, MQNIC_RB_SCHED_BLOCK_VER, index=k)

            s = SchedulerBlock(self, k, rb)
            await s.init()
            self.sched_blocks.append(s)

        assert self.sched_block_count == len(self.sched_blocks)

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
            ring_index = cpl_data[1] & ring.size_mask

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

        ring.clean_event.set()

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
            ring_index = cpl_data[1] & ring.size_mask

            self.log.info("CPL data: %s", cpl_data)

            self.log.info("Ring index: %d", ring_index)
            pkt = ring.rx_info[ring_index]

            length = cpl_data[2]

            skb = Packet()
            skb.data = pkt[:length]
            skb.queue = ring.index
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

        data = bytes(skb)

        assert len(data) < self.max_tx_mtu

        if tx_ring is not None:
            ring_index = tx_ring
        else:
            ring_index = 0

        ring = self.tx_queues[ring_index]

        while True:
            # check for space in ring
            if ring.head_ptr - ring.clean_tail_ptr < ring.full_size:
                break

            # wait for space
            ring.clean_event.clear()
            await ring.clean_event.wait()

        index = ring.head_ptr & ring.size_mask

        ring.packets += 1
        ring.bytes += len(data)

        pkt = self.driver.alloc_pkt()

        assert not ring.tx_info[index]
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
        await self.if_ctrl_rb.write_dword(MQNIC_RB_IF_CTRL_REG_TX_MTU, mtu)
        await self.if_ctrl_rb.write_dword(MQNIC_RB_IF_CTRL_REG_RX_MTU, mtu)

    async def get_rx_queue_map_offset(self, port):
        return await self.rx_queue_map_rb.read_dword(MQNIC_RB_RX_QUEUE_MAP_CH_OFFSET +
            MQNIC_RB_RX_QUEUE_MAP_CH_STRIDE*port + MQNIC_RB_RX_QUEUE_MAP_CH_REG_OFFSET)

    async def set_rx_queue_map_offset(self, port, val):
        await self.rx_queue_map_rb.write_dword(MQNIC_RB_RX_QUEUE_MAP_CH_OFFSET +
            MQNIC_RB_RX_QUEUE_MAP_CH_STRIDE*port + MQNIC_RB_RX_QUEUE_MAP_CH_REG_OFFSET, val)

    async def get_rx_queue_map_rss_mask(self, port):
        return await self.rx_queue_map_rb.read_dword(MQNIC_RB_RX_QUEUE_MAP_CH_OFFSET +
            MQNIC_RB_RX_QUEUE_MAP_CH_STRIDE*port + MQNIC_RB_RX_QUEUE_MAP_CH_REG_RSS_MASK)

    async def set_rx_queue_map_rss_mask(self, port, val):
        await self.rx_queue_map_rb.write_dword(MQNIC_RB_RX_QUEUE_MAP_CH_OFFSET +
            MQNIC_RB_RX_QUEUE_MAP_CH_STRIDE*port + MQNIC_RB_RX_QUEUE_MAP_CH_REG_RSS_MASK, val)

    async def get_rx_queue_map_app_mask(self, port):
        return await self.rx_queue_map_rb.read_dword(MQNIC_RB_RX_QUEUE_MAP_CH_OFFSET +
            MQNIC_RB_RX_QUEUE_MAP_CH_STRIDE*port + MQNIC_RB_RX_QUEUE_MAP_CH_REG_APP_MASK)

    async def set_rx_queue_map_app_mask(self, port, val):
        await self.rx_queue_map_rb.write_dword(MQNIC_RB_RX_QUEUE_MAP_CH_OFFSET +
            MQNIC_RB_RX_QUEUE_MAP_CH_STRIDE*port + MQNIC_RB_RX_QUEUE_MAP_CH_REG_APP_MASK, val)

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

        self.dev = None
        self.pool = None

        self.hw_regs = None
        self.app_hw_regs = None
        self.ram_hw_regs = None

        self.irq_sig = None
        self.irq_list = []

        self.reg_blocks = RegBlockList()
        self.fw_id_rb = None
        self.if_rb = None
        self.phc_rb = None

        self.fpga_id = None
        self.fw_id = None
        self.fw_ver = None
        self.board_id = None
        self.board_ver = None
        self.build_date = None
        self.build_time = None
        self.git_hash = None
        self.rel_info = None

        self.app_id = None

        self.if_offset = None
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

    async def init_pcie_dev(self, dev):
        assert not self.initialized
        self.initialized = True

        self.dev = dev

        self.pool = self.dev.rc.mem_pool

        await self.dev.enable_device()
        await self.dev.set_master()
        await self.dev.alloc_irq_vectors(1, MQNIC_MAX_EVENT_RINGS)

        self.hw_regs = self.dev.bar_window[0]
        self.app_hw_regs = self.dev.bar_window[2]
        self.ram_hw_regs = self.dev.bar_window[4]

        # set up MSI
        for index in range(32):
            irq = Interrupt(index, self.interrupt_handler)
            self.dev.request_irq(index, irq.interrupt)
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

        # Enumerate registers
        await self.reg_blocks.enumerate_reg_blocks(self.hw_regs)

        # Read ID registers
        self.fw_id_rb = self.reg_blocks.find(MQNIC_RB_FW_ID_TYPE, MQNIC_RB_FW_ID_VER)

        self.fpga_id = await self.fw_id_rb.read_dword(MQNIC_RB_FW_ID_REG_FPGA_ID)
        self.log.info("FPGA JTAG ID: 0x%08x", self.fpga_id)
        self.fw_id = await self.fw_id_rb.read_dword(MQNIC_RB_FW_ID_REG_FW_ID)
        self.log.info("FW ID: 0x%08x", self.fw_id)
        self.fw_ver = await self.fw_id_rb.read_dword(MQNIC_RB_FW_ID_REG_FW_VER)
        self.log.info("FW version: %d.%d.%d.%d", *self.fw_ver.to_bytes(4, 'big'))
        self.board_id = await self.fw_id_rb.read_dword(MQNIC_RB_FW_ID_REG_BOARD_ID)
        self.log.info("Board ID: 0x%08x", self.board_id)
        self.board_ver = await self.fw_id_rb.read_dword(MQNIC_RB_FW_ID_REG_BOARD_VER)
        self.log.info("Board version: %d.%d.%d.%d", *self.board_ver.to_bytes(4, 'big'))
        self.build_date = await self.fw_id_rb.read_dword(MQNIC_RB_FW_ID_REG_BUILD_DATE)
        self.log.info("Build date: %s UTC (raw: 0x%08x)", datetime.datetime.utcfromtimestamp(self.build_date).isoformat(' '), self.build_date)
        self.git_hash = await self.fw_id_rb.read_dword(MQNIC_RB_FW_ID_REG_GIT_HASH)
        self.log.info("Git hash: %08x", self.git_hash)
        self.rel_info = await self.fw_id_rb.read_dword(MQNIC_RB_FW_ID_REG_REL_INFO)
        self.log.info("Release info: %d", self.rel_info)

        rb = self.reg_blocks.find(MQNIC_RB_APP_INFO_TYPE, MQNIC_RB_APP_INFO_VER)

        if rb:
            self.app_id = await rb.read_dword(MQNIC_RB_APP_INFO_REG_ID)
            self.log.info("Application ID: 0x%08x", self.app_id)

        self.phc_rb = self.reg_blocks.find(MQNIC_RB_PHC_TYPE, MQNIC_RB_PHC_VER)

        # Enumerate interfaces
        self.if_rb = self.reg_blocks.find(MQNIC_RB_IF_TYPE, MQNIC_RB_IF_VER)
        self.interfaces = []

        if self.if_rb:
            self.if_offset = await self.if_rb.read_dword(MQNIC_RB_IF_REG_OFFSET)
            self.log.info("IF offset: %d", self.if_offset)
            self.if_count = await self.if_rb.read_dword(MQNIC_RB_IF_REG_COUNT)
            self.log.info("IF count: %d", self.if_count)
            self.if_stride = await self.if_rb.read_dword(MQNIC_RB_IF_REG_STRIDE)
            self.log.info("IF stride: 0x%08x", self.if_stride)
            self.if_csr_offset = await self.if_rb.read_dword(MQNIC_RB_IF_REG_CSR_OFFSET)
            self.log.info("IF CSR offset: 0x%08x", self.if_csr_offset)

            for k in range(self.if_count):
                i = Interface(self, k, self.hw_regs.create_window(self.if_offset + k*self.if_stride, self.if_stride))
                await i.init()
                self.interfaces.append(i)

        else:
            self.log.warning("No interface block found")

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
