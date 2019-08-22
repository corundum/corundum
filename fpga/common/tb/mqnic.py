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

from myhdl import *

import pcie

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

MQNIC_REG_GPIO_OUT               = 0x0100
MQNIC_REG_GPIO_IN                = 0x0104

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

MQNIC_PORT_REG_SCHED_COUNT                = 0x0010
MQNIC_PORT_REG_SCHED_OFFSET               = 0x0014
MQNIC_PORT_REG_SCHED_STRIDE               = 0x0018
MQNIC_PORT_REG_SCHED_TYPE                 = 0x001C
MQNIC_PORT_REG_SCHED_ENABLE               = 0x0040
MQNIC_PORT_REG_TDMA_CTRL                  = 0x0100
MQNIC_PORT_REG_TDMA_STATUS                = 0x0104
MQNIC_PORT_REG_TDMA_SCHED_START_FNS       = 0x0110
MQNIC_PORT_REG_TDMA_SCHED_START_NS        = 0x0114
MQNIC_PORT_REG_TDMA_SCHED_START_SEC_L     = 0x0118
MQNIC_PORT_REG_TDMA_SCHED_START_SEC_H     = 0x011C
MQNIC_PORT_REG_TDMA_SCHED_PERIOD_FNS      = 0x0110
MQNIC_PORT_REG_TDMA_SCHED_PERIOD_NS       = 0x0114
MQNIC_PORT_REG_TDMA_SCHED_PERIOD_SEC_L    = 0x0118
MQNIC_PORT_REG_TDMA_SCHED_PERIOD_SEC_H    = 0x011C
MQNIC_PORT_REG_TDMA_TIMESLOT_PERIOD_FNS   = 0x0110
MQNIC_PORT_REG_TDMA_TIMESLOT_PERIOD_NS    = 0x0114
MQNIC_PORT_REG_TDMA_TIMESLOT_PERIOD_SEC_L = 0x0118
MQNIC_PORT_REG_TDMA_TIMESLOT_PERIOD_SEC_H = 0x011C
MQNIC_PORT_REG_TDMA_ACTIVE_PERIOD_FNS     = 0x0110
MQNIC_PORT_REG_TDMA_ACTIVE_PERIOD_NS      = 0x0114
MQNIC_PORT_REG_TDMA_ACTIVE_PERIOD_SEC_L   = 0x0118
MQNIC_PORT_REG_TDMA_ACTIVE_PERIOD_SEC_H   = 0x011C

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


class Packet(object):
    def __init__(self, data=b''):
        self.data = data
        self.timestamp_s = None
        self.timestamp_ns = None
        self.rx_checksum = None

    def __repr__(self):
        return (
                ('Packet(data=%s, ' % repr(self.data)) +
                ('timestamp_s=%d, ' % self.timestamp_s) +
                ('timestamp_ns=%d, ' % self.timestamp_ns) +
                ('rx_checksum=0x%x)' % self.rx_checksum)
            )

    def __iter__(self):
        return self.data.__iter__()


class EqRing(object):
    def __init__(self, interface, size, stride, index, hw_addr):
        self.interface = interface
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
        self.hw_addr = hw_addr
        self.hw_head_ptr = hw_addr+MQNIC_EVENT_QUEUE_HEAD_PTR_REG
        self.hw_tail_ptr = hw_addr+MQNIC_EVENT_QUEUE_TAIL_PTR_REG

    def init(self):
        self.buf_size = self.size*self.stride
        self.buf_dma, self.buf = self.rc.alloc_region(self.buf_size)

        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG, 0) # active, log size
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_EVENT_QUEUE_BASE_ADDR_REG, self.buf_dma & 0xffffffff) # base address
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_EVENT_QUEUE_BASE_ADDR_REG+4, self.buf_dma >> 32) # base address
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_EVENT_QUEUE_INTERRUPT_INDEX_REG, 0) # interrupt index
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_EVENT_QUEUE_HEAD_PTR_REG, self.head_ptr & self.hw_ptr_mask) # head pointer
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_EVENT_QUEUE_TAIL_PTR_REG, self.tail_ptr & self.hw_ptr_mask) # tail pointer
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_size) # active, log size

    def activate(self, int_index):
        self.interrupt_index = int_index

        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG, 0) # active, log size
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_EVENT_QUEUE_BASE_ADDR_REG, self.buf_dma & 0xffffffff) # base address
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_EVENT_QUEUE_BASE_ADDR_REG+4, self.buf_dma >> 32) # base address
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_EVENT_QUEUE_INTERRUPT_INDEX_REG, int_index) # interrupt index
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_EVENT_QUEUE_HEAD_PTR_REG, self.head_ptr & self.hw_ptr_mask) # head pointer
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_EVENT_QUEUE_TAIL_PTR_REG, self.tail_ptr & self.hw_ptr_mask) # tail pointer
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_size | MQNIC_EVENT_QUEUE_ACTIVE_MASK) # active, log size

    def deactivate(self):
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_EVENT_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_size) # active, log size
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_EVENT_QUEUE_INTERRUPT_INDEX_REG, self.interrupt_index) # interrupt index

    def empty(self):
        return self.head_ptr == self.tail_ptr

    def full(self):
        return self.head_ptr - self.tail_ptr >= self.size

    def read_head_ptr(self):
        val = yield from self.rc.mem_read_dword(self.hw_head_ptr)
        self.head_ptr += (val - self.head_ptr) & self.hw_ptr_mask

    def write_tail_ptr(self):
        yield from self.rc.mem_write_dword(self.hw_tail_ptr, self.tail_ptr & self.hw_ptr_mask)

    def arm(self):
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_EVENT_QUEUE_INTERRUPT_INDEX_REG, self.interrupt_index | MQNIC_EVENT_QUEUE_ARM_MASK) # interrupt index

    def process(self):
        if not self.interface.port_up:
            return

        print("Process event queue")

        yield from self.read_head_ptr()

        eq_tail_ptr = self.tail_ptr
        eq_index = eq_tail_ptr & self.size_mask

        print("%d events in queue" % (self.head_ptr - eq_tail_ptr))

        while (self.head_ptr != eq_tail_ptr):
            event_data = struct.unpack_from("<HH", self.buf, eq_index*MQNIC_EVENT_SIZE)

            print("Event data: "+repr(event_data))

            if event_data[0] == 0:
                # transmit completion
                cq = self.interface.tx_cpl_queues[event_data[1]]
                yield from self.interface.process_tx_cq(cq)
                yield from cq.arm()
            elif event_data[0] == 1:
                # receive completion
                cq = self.interface.rx_cpl_queues[event_data[1]]
                yield from self.interface.process_rx_cq(cq)
                yield from cq.arm()

            eq_tail_ptr += 1
            eq_index = eq_tail_ptr & self.size_mask

        self.tail_ptr = eq_tail_ptr
        yield from self.write_tail_ptr()


class CqRing(object):
    def __init__(self, interface, size, stride, index, hw_addr):
        self.interface = interface
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
        self.hw_addr = hw_addr
        self.hw_head_ptr = hw_addr+MQNIC_CPL_QUEUE_HEAD_PTR_REG
        self.hw_tail_ptr = hw_addr+MQNIC_CPL_QUEUE_TAIL_PTR_REG

    def init(self):
        self.buf_size = self.size*self.stride
        self.buf_dma, self.buf = self.rc.alloc_region(self.buf_size)

        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_CPL_QUEUE_ACTIVE_LOG_SIZE_REG, 0) # active, log size
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_CPL_QUEUE_BASE_ADDR_REG, self.buf_dma & 0xffffffff) # base address
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_CPL_QUEUE_BASE_ADDR_REG+4, self.buf_dma >> 32) # base address
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_CPL_QUEUE_INTERRUPT_INDEX_REG, 0) # event index
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_CPL_QUEUE_HEAD_PTR_REG, self.head_ptr & self.hw_ptr_mask) # head pointer
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_CPL_QUEUE_TAIL_PTR_REG, self.tail_ptr & self.hw_ptr_mask) # tail pointer
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_CPL_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_size) # active, log size

    def activate(self, int_index):
        self.interrupt_index = int_index

        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_CPL_QUEUE_ACTIVE_LOG_SIZE_REG, 0) # active, log size
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_CPL_QUEUE_BASE_ADDR_REG, self.buf_dma & 0xffffffff) # base address
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_CPL_QUEUE_BASE_ADDR_REG+4, self.buf_dma >> 32) # base address
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_CPL_QUEUE_INTERRUPT_INDEX_REG, int_index) # event index
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_CPL_QUEUE_HEAD_PTR_REG, self.head_ptr & self.hw_ptr_mask) # head pointer
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_CPL_QUEUE_TAIL_PTR_REG, self.tail_ptr & self.hw_ptr_mask) # tail pointer
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_CPL_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_size | MQNIC_CPL_QUEUE_ACTIVE_MASK) # active, log size

    def deactivate(self):
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_CPL_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_size) # active, log size
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_CPL_QUEUE_CPL_QUEUE_INDEX_REG, int_index) # event index

    def empty(self):
        return self.head_ptr == self.tail_ptr

    def full(self):
        return self.head_ptr - self.tail_ptr >= self.size

    def read_head_ptr(self):
        val = yield from self.rc.mem_read_dword(self.hw_head_ptr)
        self.head_ptr += (val - self.head_ptr) & self.hw_ptr_mask

    def write_tail_ptr(self):
        yield from self.rc.mem_write_dword(self.hw_tail_ptr, self.tail_ptr & self.hw_ptr_mask)

    def arm(self):
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_CPL_QUEUE_INTERRUPT_INDEX_REG, self.interrupt_index | MQNIC_CPL_QUEUE_ARM_MASK) # event index


class TxRing(object):
    def __init__(self, interface, size, stride, index, hw_addr):
        self.interface = interface
        self.driver = interface.driver
        self.rc = interface.driver.rc
        self.log_size = size.bit_length() - 1
        self.size = 2**self.log_size
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
        self.hw_addr = hw_addr
        self.hw_head_ptr = hw_addr+MQNIC_QUEUE_HEAD_PTR_REG
        self.hw_tail_ptr = hw_addr+MQNIC_QUEUE_TAIL_PTR_REG

    def init(self):
        self.tx_info = [None]*self.size

        self.buf_size = self.size*self.stride
        self.buf_dma, self.buf = self.rc.alloc_region(self.buf_size)

        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG, 0) # active, log size
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_BASE_ADDR_REG, self.buf_dma & 0xffffffff) # base address
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_BASE_ADDR_REG+4, self.buf_dma >> 32) # base address
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_CPL_QUEUE_INDEX_REG, 0) # completion queue index
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_HEAD_PTR_REG, self.head_ptr & self.hw_ptr_mask) # head pointer
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_TAIL_PTR_REG, self.tail_ptr & self.hw_ptr_mask) # tail pointer
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_size) # active, log size

    def activate(self, cpl_index):
        self.cpl_index = cpl_index

        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG, 0) # active, log size
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_BASE_ADDR_REG, self.buf_dma & 0xffffffff) # base address
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_BASE_ADDR_REG+4, self.buf_dma >> 32) # base address
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_CPL_QUEUE_INDEX_REG, cpl_index) # completion queue index
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_HEAD_PTR_REG, self.head_ptr & self.hw_ptr_mask) # head pointer
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_TAIL_PTR_REG, self.tail_ptr & self.hw_ptr_mask) # tail pointer
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_size | MQNIC_QUEUE_ACTIVE_MASK) # active, log size

    def deactivate(self):
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_size) # active, log size

    def empty(self):
        return self.head_ptr == self.clean_tail_ptr

    def full(self):
        return self.head_ptr - self.clean_tail_ptr >= self.full_size

    def read_tail_ptr(self):
        val = yield from self.rc.mem_read_dword(self.hw_tail_ptr)
        self.tail_ptr += (val - self.tail_ptr) & self.hw_ptr_mask

    def write_head_ptr(self):
        yield from self.rc.mem_write_dword(self.hw_head_ptr, self.head_ptr & self.hw_ptr_mask)

    def free_desc(self, index):
        pkt = self.tx_info[index]
        self.driver.free_pkt(pkt)
        self.tx_info[index] = None

    def free_buf(self):
        while not self.empty():
            index = self.clean_tail_ptr & self.size_mask
            self.free_desc(index)
            self.clean_tail_ptr += 1


class RxRing(object):
    def __init__(self, interface, size, stride, index, hw_addr):
        self.interface = interface
        self.driver = interface.driver
        self.rc = interface.driver.rc
        self.log_size = size.bit_length() - 1
        self.size = 2**self.log_size
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
        self.hw_addr = hw_addr
        self.hw_head_ptr = hw_addr+MQNIC_QUEUE_HEAD_PTR_REG
        self.hw_tail_ptr = hw_addr+MQNIC_QUEUE_TAIL_PTR_REG

    def init(self):
        self.rx_info = [None]*self.size

        self.buf_size = self.size*self.stride
        self.buf_dma, self.buf = self.rc.alloc_region(self.buf_size)

        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG, 0) # active, log size
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_BASE_ADDR_REG, self.buf_dma & 0xffffffff) # base address
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_BASE_ADDR_REG+4, self.buf_dma >> 32) # base address
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_CPL_QUEUE_INDEX_REG, 0) # completion queue index
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_HEAD_PTR_REG, self.head_ptr & self.hw_ptr_mask) # head pointer
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_TAIL_PTR_REG, self.tail_ptr & self.hw_ptr_mask) # tail pointer
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_size) # active, log size

    def activate(self, cpl_index):
        self.cpl_index = cpl_index

        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG, 0) # active, log size
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_BASE_ADDR_REG, self.buf_dma & 0xffffffff) # base address
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_BASE_ADDR_REG+4, self.buf_dma >> 32) # base address
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_CPL_QUEUE_INDEX_REG, cpl_index) # completion queue index
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_HEAD_PTR_REG, self.head_ptr & self.hw_ptr_mask) # head pointer
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_TAIL_PTR_REG, self.tail_ptr & self.hw_ptr_mask) # tail pointer
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_size | MQNIC_QUEUE_ACTIVE_MASK) # active, log size

        yield from self.refill_buffers()

    def deactivate(self):
        yield from self.rc.mem_write_dword(self.hw_addr+MQNIC_QUEUE_ACTIVE_LOG_SIZE_REG, self.log_size) # active, log size

    def empty(self):
        return self.head_ptr == self.clean_tail_ptr

    def full(self):
        return self.head_ptr - self.clean_tail_ptr >= self.full_size

    def read_tail_ptr(self):
        val = yield from self.rc.mem_read_dword(self.hw_tail_ptr)
        self.tail_ptr += (val - self.tail_ptr) & self.hw_ptr_mask

    def write_head_ptr(self):
        yield from self.rc.mem_write_dword(self.hw_head_ptr, self.head_ptr & self.hw_ptr_mask)

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

        # write descriptor
        struct.pack_into("<LLQ", self.buf, index*16, 0, len(pkt[1]), pkt[0])

    def refill_buffers(self):
        missing = self.size - (self.head_ptr - self.clean_tail_ptr)

        if missing < 8:
            return

        for k in range(missing):
            self.prepare_desc(self.head_ptr & self.size_mask)
            self.head_ptr += 1

        yield from self.write_head_ptr()


class Scheduler(object):
    def __init__(self, port, index, hw_addr):
        self.port = port
        self.interface = port.interface
        self.driver = port.interface.driver
        self.rc = port.interface.driver.rc
        self.index = index
        self.hw_addr = hw_addr


class Port(object):
    def __init__(self, interface, index, hw_addr):
        self.interface = interface
        self.driver = interface.driver
        self.rc = interface.driver.rc
        self.index = index
        self.hw_addr = hw_addr

        self.port_id = None
        self.port_features = None
        self.sched_count = None
        self.sched_offset = None
        self.sched_stride = None
        self.sched_type = None

    def init(self):
        # Read ID registers
        self.port_id = yield from self.driver.rc.mem_read_dword(self.hw_addr+MQNIC_PORT_REG_PORT_ID)
        print("Port ID: {:#010x}".format(self.port_id))
        self.port_features = yield from self.driver.rc.mem_read_dword(self.hw_addr+MQNIC_PORT_REG_PORT_FEATURES)
        print("Port features: {:#010x}".format(self.port_features))

        self.sched_count = yield from self.driver.rc.mem_read_dword(self.hw_addr+MQNIC_PORT_REG_SCHED_COUNT)
        print("Scheduler count: {}".format(self.sched_count))
        self.sched_offset = yield from self.driver.rc.mem_read_dword(self.hw_addr+MQNIC_PORT_REG_SCHED_OFFSET)
        print("Scheduler offset: {:#010x}".format(self.sched_offset))
        self.sched_stride = yield from self.driver.rc.mem_read_dword(self.hw_addr+MQNIC_PORT_REG_SCHED_STRIDE)
        print("Scheduler stride: {:#010x}".format(self.sched_stride))
        self.sched_type = yield from self.driver.rc.mem_read_dword(self.hw_addr+MQNIC_PORT_REG_SCHED_TYPE)
        print("Scheduler type: {:#010x}".format(self.sched_type))

        self.schedulers = []

        for k in range(self.sched_count):
            p = Scheduler(self, k, self.hw_addr + self.sched_offset + k*self.sched_stride)
            self.schedulers.append(p)


class Interface(object):
    def __init__(self, driver, index, hw_addr):
        self.driver = driver
        self.index = index
        self.hw_addr = hw_addr
        self.csr_hw_addr = hw_addr+driver.if_csr_offset
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

        self.pkt_rx_queue = []
        self.pkt_rx_sync = Signal(bool(0))

    def init(self):
        self.driver.rc.msi_register_callback(self.driver.dev_id, self.interrupt, self.index)

        # Read ID registers
        self.if_id = yield from self.driver.rc.mem_read_dword(self.csr_hw_addr+MQNIC_IF_REG_IF_ID)
        print("IF ID: {:#010x}".format(self.if_id))
        self.if_features = yield from self.driver.rc.mem_read_dword(self.csr_hw_addr+MQNIC_IF_REG_IF_FEATURES)
        print("IF features: {:#010x}".format(self.if_features))

        self.event_queue_count = yield from self.driver.rc.mem_read_dword(self.csr_hw_addr+MQNIC_IF_REG_EVENT_QUEUE_COUNT)
        print("Event queue count: {}".format(self.event_queue_count))
        self.event_queue_offset = yield from self.driver.rc.mem_read_dword(self.csr_hw_addr+MQNIC_IF_REG_EVENT_QUEUE_OFFSET)
        print("Event queue offset: {:#010x}".format(self.event_queue_offset))
        self.tx_queue_count = yield from self.driver.rc.mem_read_dword(self.csr_hw_addr+MQNIC_IF_REG_TX_QUEUE_COUNT)
        print("TX queue count: {}".format(self.tx_queue_count))
        self.tx_queue_offset = yield from self.driver.rc.mem_read_dword(self.csr_hw_addr+MQNIC_IF_REG_TX_QUEUE_OFFSET)
        print("TX queue offset: {:#010x}".format(self.tx_queue_offset))
        self.tx_cpl_queue_count = yield from self.driver.rc.mem_read_dword(self.csr_hw_addr+MQNIC_IF_REG_TX_CPL_QUEUE_COUNT)
        print("TX completion queue count: {}".format(self.tx_cpl_queue_count))
        self.tx_cpl_queue_offset = yield from self.driver.rc.mem_read_dword(self.csr_hw_addr+MQNIC_IF_REG_TX_CPL_QUEUE_OFFSET)
        print("TX completion queue offset: {:#010x}".format(self.tx_cpl_queue_offset))
        self.rx_queue_count = yield from self.driver.rc.mem_read_dword(self.csr_hw_addr+MQNIC_IF_REG_RX_QUEUE_COUNT)
        print("RX queue count: {}".format(self.rx_queue_count))
        self.rx_queue_offset = yield from self.driver.rc.mem_read_dword(self.csr_hw_addr+MQNIC_IF_REG_RX_QUEUE_OFFSET)
        print("RX queue offset: {:#010x}".format(self.rx_queue_offset))
        self.rx_cpl_queue_count = yield from self.driver.rc.mem_read_dword(self.csr_hw_addr+MQNIC_IF_REG_RX_CPL_QUEUE_COUNT)
        print("RX completion queue count: {}".format(self.rx_cpl_queue_count))
        self.rx_cpl_queue_offset = yield from self.driver.rc.mem_read_dword(self.csr_hw_addr+MQNIC_IF_REG_RX_CPL_QUEUE_OFFSET)
        print("RX completion queue offset: {:#010x}".format(self.rx_cpl_queue_offset))
        self.port_count = yield from self.driver.rc.mem_read_dword(self.csr_hw_addr+MQNIC_IF_REG_PORT_COUNT)
        print("Port count: {}".format(self.port_count))
        self.port_offset = yield from self.driver.rc.mem_read_dword(self.csr_hw_addr+MQNIC_IF_REG_PORT_OFFSET)
        print("Port offset: {:#010x}".format(self.port_offset))
        self.port_stride = yield from self.driver.rc.mem_read_dword(self.csr_hw_addr+MQNIC_IF_REG_PORT_STRIDE)
        print("Port stride: {:#010x}".format(self.port_stride))

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
            q = EqRing(self, 1024, 16, self.index, self.hw_addr + self.event_queue_offset + k*MQNIC_EVENT_QUEUE_STRIDE)
            yield from q.init()
            self.event_queues.append(q)

        for k in range(self.tx_queue_count):
            q = TxRing(self, 1024, 16, k, self.hw_addr + self.tx_queue_offset + k*MQNIC_QUEUE_STRIDE)
            yield from q.init()
            self.tx_queues.append(q)

        for k in range(self.tx_cpl_queue_count):
            q = CqRing(self, 1024, 32, k, self.hw_addr + self.tx_cpl_queue_offset + k*MQNIC_CPL_QUEUE_STRIDE)
            yield from q.init()
            self.tx_cpl_queues.append(q)

        for k in range(self.rx_queue_count):
            q = RxRing(self, 1024, 16, k, self.hw_addr + self.rx_queue_offset + k*MQNIC_QUEUE_STRIDE)
            yield from q.init()
            self.rx_queues.append(q)

        for k in range(self.rx_cpl_queue_count):
            q = CqRing(self, 1024, 32, k, self.hw_addr + self.rx_cpl_queue_offset + k*MQNIC_CPL_QUEUE_STRIDE)
            yield from q.init()
            self.rx_cpl_queues.append(q)

        for k in range(self.port_count):
            p = Port(self, k, self.hw_addr + self.port_offset + k*self.port_stride)
            yield from p.init()
            self.ports.append(p)

    def open(self):
        for q in self.event_queues:
            yield from q.activate(self.index) # TODO?
            q.handler = None # TODO
            yield from q.arm()

        for q in self.rx_cpl_queues:
            yield from q.activate(0) # TODO
            q.ring_index = q.index
            q.handler = None # TODO
            yield from q.arm()

        for q in self.rx_queues:
            yield from q.activate(q.index)

        for q in self.tx_cpl_queues:
            yield from q.activate(0) # TODO
            q.ring_index = q.index
            q.handler = None # TODO
            yield from q.arm()

        for q in self.tx_queues:
            yield from q.activate(q.index)

        self.port_up = True

    def close(self):
        self.port_up = False

        for q in self.tx_queues:
            yield from q.deactivate()

        for q in self.tx_cpl_queues:
            yield from q.deactivate()

        for q in self.rx_queues:
            yield from q.deactivate()

        for q in self.rx_cpl_queues:
            yield from q.deactivate()

        for q in self.event_queues:
            yield from q.deactivate()

        yield delay(10000)

        for q in self.tx_queues:
            yield from q.free_buf()

        for q in self.rx_queues:
            yield from q.free_buf()

    def interrupt(self):
        print("Interface interrupt")
        if self.interrupt_running:
            self.interrupt_pending += 1
            print("************************ interrupt was running")
            return
        self.interrupt_running = True
        for eq in self.event_queues:
            yield from eq.process()
            yield from eq.arm()
        self.interrupt_running = False
        print("Device interrupt done")

        while self.interrupt_pending:
            self.interrupt_pending -= 1
            yield from self.interrupt()

    def process_tx_cq(self, cq_ring):
        ring = self.tx_queues[cq_ring.ring_index]

        if not self.port_up:
            return

        # process completion queue
        yield from cq_ring.read_head_ptr()

        cq_tail_ptr = cq_ring.tail_ptr
        cq_index = cq_tail_ptr & cq_ring.size_mask

        while (cq_ring.head_ptr != cq_tail_ptr):
            cpl_data = struct.unpack_from("<HHHxxQ", cq_ring.buf, cq_index*MQNIC_CPL_SIZE)
            ring_index = cpl_data[1]

            print(cpl_data)

            print("Ring index %d" % ring_index)

            ring.free_desc(ring_index)

            cq_tail_ptr += 1
            cq_index = cq_tail_ptr & cq_ring.size_mask

        cq_ring.tail_ptr = cq_tail_ptr
        yield from cq_ring.write_tail_ptr()

        # process ring
        yield from ring.read_tail_ptr()

        ring_clean_tail_ptr = ring.clean_tail_ptr
        ring_index = ring_clean_tail_ptr & ring.size_mask

        while (ring_clean_tail_ptr != ring.tail_ptr):
            if ring.tx_info[ring_index]:
                break

            ring_clean_tail_ptr += 1
            ring_index = ring_clean_tail_ptr & ring.size_mask

        ring.clean_tail_ptr = ring_clean_tail_ptr

    def process_rx_cq(self, cq_ring):
        ring = self.rx_queues[cq_ring.ring_index]

        if not self.port_up:
            return

        # process completion queue
        yield from cq_ring.read_head_ptr()

        cq_tail_ptr = cq_ring.tail_ptr
        cq_index = cq_tail_ptr & cq_ring.size_mask

        while (cq_ring.head_ptr != cq_tail_ptr):
            cpl_data = struct.unpack_from("<HHHxxLHH", cq_ring.buf, cq_index*MQNIC_CPL_SIZE)
            ring_index = cpl_data[1]

            print(cpl_data)

            print("Ring index %d" % ring_index)
            pkt = ring.rx_info[ring_index]

            length = cpl_data[2]

            skb = Packet()
            skb.data = pkt[1][:length]
            skb.timestamp_ns = cpl_data[3]
            skb.timestamp_s = cpl_data[4]
            skb.rx_checksum = cpl_data[5]

            print(skb)

            self.pkt_rx_queue.append(skb)
            self.pkt_rx_sync.next = not self.pkt_rx_sync

            ring.free_desc(ring_index)

            cq_tail_ptr += 1
            cq_index = cq_tail_ptr & cq_ring.size_mask

        cq_ring.tail_ptr = cq_tail_ptr
        yield from cq_ring.write_tail_ptr()

        # process ring
        yield from ring.read_tail_ptr()

        ring_clean_tail_ptr = ring.clean_tail_ptr
        ring_index = ring_clean_tail_ptr & ring.size_mask

        while (ring_clean_tail_ptr != ring.tail_ptr):
            if ring.rx_info[ring_index]:
                break

            ring_clean_tail_ptr += 1
            ring_index = ring_clean_tail_ptr & ring.size_mask

        ring.clean_tail_ptr = ring_clean_tail_ptr

        # replenish buffers
        yield from ring.refill_buffers()

    def start_xmit(self, skb, tx_ring=None, csum_start=None, csum_offset=None):
        if not self.port_up:
            return

        if isinstance(skb, Packet):
            data = skb.data
        else:
            data = skb

        data = data[:2048] # TODO
        ring_index = tx_ring # TODO!

        ring = self.tx_queues[ring_index];

        tail_ptr = ring.tail_ptr

        index = ring.head_ptr & ring.size_mask

        ring.packets += 1
        ring.bytes += len(data)

        pkt = self.driver.alloc_pkt()

        ring.tx_info[index] = pkt

        # put data in packet buffer
        pkt[1][0:len(data)] = data

        csum_cmd = 0

        if csum_start is not None and csum_offset is not None:
            csum_cmd = 0x8000 | (csum_offset << 8) | csum_start

        # write descriptor
        struct.pack_into("<HHLQ", ring.buf, index*16, 0, csum_cmd, len(data), pkt[0])

        ring.head_ptr += 1;

        yield from ring.write_head_ptr()

    def recv(self):
        if self.pkt_rx_queue:
            return self.pkt_rx_queue.pop(0)
        return None

    def wait(self):
        yield self.pkt_rx_sync


class Driver(object):
    def __init__(self, rc):
        self.rc = rc
        self.dev_id = None
        self.rc_tree_ent = None
        self.hw_addr = None

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

        self.pkt_buf_size = 2048
        self.allocated_packets = []
        self.free_packets = []

    def init_dev(self, dev_id):
        assert not self.initialized
        self.initialized = True

        self.dev_id = dev_id
        self.rc_tree_ent = self.rc.tree.find_dev(dev_id)
        self.hw_addr = self.rc_tree_ent.bar[0] & 0xfffffff0

        # Read ID registers
        self.fw_id = yield from self.rc.mem_read_dword(self.hw_addr+MQNIC_REG_FW_ID)
        print("FW ID: {:#010x}".format(self.fw_id))
        self.fw_ver = yield from self.rc.mem_read_dword(self.hw_addr+MQNIC_REG_FW_VER)
        print("FW version: {}.{}".format(self.fw_ver >> 16, self.fw_ver & 0xffff))
        self.board_id = yield from self.rc.mem_read_dword(self.hw_addr+MQNIC_REG_BOARD_ID)
        print("Board ID: {:#010x}".format(self.board_id))
        self.board_ver = yield from self.rc.mem_read_dword(self.hw_addr+MQNIC_REG_BOARD_VER)
        print("Board version: {}.{}".format(self.board_ver >> 16, self.board_ver & 0xffff))

        self.phc_count = yield from self.rc.mem_read_dword(self.hw_addr+MQNIC_REG_PHC_COUNT)
        print("PHC count: {}".format(self.phc_count))
        self.phc_offset = yield from self.rc.mem_read_dword(self.hw_addr+MQNIC_REG_PHC_OFFSET)
        print("PHC offset: {:#010x}".format(self.phc_offset))

        self.if_count = yield from self.rc.mem_read_dword(self.hw_addr+MQNIC_REG_IF_COUNT)
        print("IF count: {}".format(self.if_count))
        self.if_stride = yield from self.rc.mem_read_dword(self.hw_addr+MQNIC_REG_IF_STRIDE)
        print("IF stride: {:#010x}".format(self.if_stride))
        self.if_csr_offset = yield from self.rc.mem_read_dword(self.hw_addr+MQNIC_REG_IF_CSR_OFFSET)
        print("IF CSR offset: {:#010x}".format(self.if_csr_offset))

        self.interfaces = []

        for k in range(self.if_count):
            i = Interface(self, k, self.hw_addr+k*self.if_stride)
            yield from i.init()
            self.interfaces.append(i)

    def alloc_pkt(self):
        if self.free_packets:
            return self.free_packets.pop()

        pkt = self.rc.alloc_region(self.pkt_buf_size)
        self.allocated_packets.append(pkt)
        return pkt

    def free_pkt(self, pkt):
        assert pkt is not None
        assert pkt in self.allocated_packets
        self.free_packets.append(pkt)


