"""

Copyright (c) 2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

"""

import math
import struct
from myhdl import *

from pcie import *


REQ_MEM_READ        = 0b0000
REQ_MEM_WRITE       = 0b0001
REQ_IO_READ         = 0b0010
REQ_IO_WRITE        = 0b0011
REQ_MEM_FETCH_ADD   = 0b0100
REQ_MEM_SWAP        = 0b0101
REQ_MEM_CAS         = 0b0110
REQ_MEM_READ_LOCKED = 0b0111
REQ_CFG_READ_0      = 0b1000
REQ_CFG_READ_1      = 0b1001
REQ_CFG_WRITE_0     = 0b1010
REQ_CFG_WRITE_1     = 0b1011
REQ_MSG             = 0b1100
REQ_MSG_VENDOR      = 0b1101
REQ_MSG_ATS         = 0b1110

RC_ERROR_NORMAL_TERMINATION = 0b0000
RC_ERROR_POISONED           = 0b0001
RC_ERROR_BAD_STATUS         = 0b0010
RC_ERROR_INVALID_LENGTH     = 0b0011
RC_ERROR_MISMATCH           = 0b0100
RC_ERROR_INVALID_ADDRESS    = 0b0101
RC_ERROR_INVALID_TAG        = 0b0110
RC_ERROR_TIMEOUT            = 0b1001
RC_ERROR_FLR                = 0b1000


def dword_parity(d):
    d ^= d >> 4
    d ^= d >> 2
    d ^= d >> 1
    p = d & 0x1
    p |= (d & 0x100) >> 7
    p |= (d & 0x10000) >> 14
    p |= (d & 0x1000000) >> 21
    return p


class USPcieFrame(object):
    def __init__(self, frame=None):
        self.data = []
        self.byte_en = []
        self.parity = []
        self.first_be = 0
        self.last_be = 0
        self.discontinue = False
        self.seq_num = 0

        if isinstance(frame, USPcieFrame):
            self.data = list(frame.data)
            self.byte_en = list(frame.byte_en)
            self.parity = list(frame.parity)
            self.first_be = frame.first_be
            self.last_be = frame.last_be
            self.discontinue = frame.discontinue
            self.seq_num = frame.seq_num

    def update_parity(self):
        self.parity = [dword_parity(d) ^ 0xf for d in self.data]

    def check_parity(self):
        return self.parity == [dword_parity(d) ^ 0xf for d in self.data]

    def __eq__(self, other):
        if isinstance(other, TLP_us):
            return (
                    self.data == other.data and
                    self.byte_en == other.byte_en and
                    self.parity == other.parity and
                    self.first_be == other.first_be and
                    self.last_be == other.last_be and
                    self.discontinue == other.discontinue and
                    self.seq_num == other.seq_num
                )
        return False

    def __repr__(self):
        return (
                ('USPcieFrame(data=[{}], '.format(', '.join('{:#010x}'.format(x) for x in self.data))) +
                ('byte_en=[{}], '.format(', '.join(hex(x) for x in self.byte_en))) +
                ('parity=[{}], '.format(', '.join(hex(x) for x in self.parity))) +
                ('first_be={:#x}, '.format(self.first_be)) +
                ('last_be={:#x}, '.format(self.last_be)) +
                ('discontinue={}, '.format(self.discontinue)) +
                ('seq_num={})'.format(self.seq_num))
            )


class TLP_us(TLP):
    def __init__(self, tlp=None):
        super(TLP_us, self).__init__(tlp)
        self.bar_id = 0
        self.bar_aperture = 0
        self.completer_id_enable = False
        self.requester_id_enable = False
        self.discontinue = False
        self.seq_num = 0
        self.error_code = RC_ERROR_NORMAL_TERMINATION

        if isinstance(tlp, TLP_us):
            self.bar_id = tlp.bar_id
            self.bar_aperture = tlp.bar_aperture
            self.completer_id_enable = tlp.completer_id_enable
            self.requester_id_enable = tlp.requester_id_enable
            self.discontinue = tlp.discontinue
            self.seq_num = tlp.seq_num
            self.error_code = tlp.error_code

    def pack_us_cq(self):
        pkt = USPcieFrame()

        if (self.fmt_type == TLP_IO_READ or self.fmt_type == TLP_IO_WRITE or
                self.fmt_type == TLP_MEM_READ or self.fmt_type == TLP_MEM_READ_64 or
                self.fmt_type == TLP_MEM_WRITE or self.fmt_type == TLP_MEM_WRITE_64):
            # Completer Request descriptor
            l = self.at & 0x3
            l |= self.address & 0xfffffffc
            pkt.data.append(l)
            l = (self.address & 0xffffffff00000000) >> 32
            pkt.data.append(l)
            l = self.length & 0x7ff
            if self.fmt_type == TLP_MEM_READ or self.fmt_type == TLP_MEM_READ_64:
                l |= REQ_MEM_READ << 11
            elif self.fmt_type == TLP_MEM_WRITE or self.fmt_type == TLP_MEM_WRITE_64:
                l |= REQ_MEM_WRITE << 11
            elif self.fmt_type == TLP_IO_READ:
                l |= REQ_IO_READ << 11
            elif self.fmt_type == TLP_IO_WRITE:
                l |= REQ_IO_WRITE << 11
            elif self.fmt_type == TLP_FETCH_ADD or self.fmt_type == TLP_FETCH_ADD_64:
                l |= REQ_MEM_FETCH_ADD << 11
            elif self.fmt_type == TLP_SWAP or self.fmt_type == TLP_SWAP_64:
                l |= REQ_MEM_SWAP << 11
            elif self.fmt_type == TLP_CAS or self.fmt_type == TLP_CAS_64:
                l |= REQ_MEM_CAS << 11
            elif self.fmt_type == TLP_MEM_READ_LOCKED or self.fmt_type == TLP_MEM_READ_LOCKED_64:
                l |= REQ_MEM_READ_LOCKED << 11
            l |= int(self.requester_id) << 16
            pkt.data.append(l)
            l = (self.tag & 0xff)
            l |= (self.completer_id.function & 0xff) << 8
            l |= (self.bar_id & 0x7) << 16
            l |= (self.bar_aperture & 0x3f) << 19
            l |= (self.tc & 0x7) << 25
            l |= (self.attr & 0x7) << 28
            pkt.data.append(l)

            pkt.first_be = self.first_be
            pkt.last_be = self.last_be

            pkt.discontinue = self.discontinue

            # payload data
            pkt.data += self.data

            # compute byte enables
            pkt.byte_en = [0]*4

            if len(self.data) >= 1:
                pkt.byte_en += [self.first_be]
            if len(self.data) > 2:
                pkt.byte_en += [0xf] * (len(self.data)-2)
            if len(self.data) > 1:
                pkt.byte_en += [self.last_be]

            # compute parity
            pkt.update_parity()
        else:
            raise Exception("Invalid packet type for interface")

        return pkt

    def unpack_us_cq(self, pkt, check_parity=False):
        req_type = (pkt.data[2] >> 11) & 0xf

        if req_type == REQ_MEM_READ:
            self.fmt_type = TLP_MEM_READ
        elif req_type == REQ_MEM_WRITE:
            self.fmt_type = TLP_MEM_WRITE
        elif req_type == REQ_IO_READ:
            self.fmt_type = TLP_IO_READ
        elif req_type == REQ_IO_WRITE:
            self.fmt_type = TLP_IO_WRITE
        elif req_type == REQ_MEM_FETCH_ADD:
            self.fmt_type = TLP_FETCH_ADD
        elif req_type == REQ_MEM_SWAP:
            self.fmt_type = TLP_SWAP
        elif req_type == REQ_MEM_CAS:
            self.fmt_type = TLP_CAS
        elif req_type == REQ_MEM_READ_LOCKED:
            self.fmt_type = TLP_MEM_READ_LOCKED
        else:
            raise Exception("Invalid packet type")

        self.length = pkt.data[2] & 0x7ff
        self.requester_id = PcieId.from_int(pkt.data[2] >> 16)
        self.tag = pkt.data[3] & 0xff
        self.tc = (pkt.data[3] >> 25) & 0x7
        self.attr = (pkt.data[3] >> 28) & 0x7

        if req_type & 8 == 0:
            # memory, IO, or atomic operation
            self.at = pkt.data[0] & 3
            self.address = (pkt.data[1] << 32) | (pkt.data[0] & 0xfffffffc)
            if self.address > 0xffffffff:
                if self.fmt == FMT_3DW:
                    self.fmt = FMT_4DW
                elif self.fmt == FMT_3DW_DATA:
                    self.fmt = FMT_4DW_DATA
            self.completer_id = PcieId(0, 0, (pkt.data[3] >> 8) & 0xff)
            self.bar_id = (pkt.data[3] >> 16) & 7
            self.bar_aperture = (pkt.data[3] >> 19) & 0x3f

            self.first_be = pkt.first_be
            self.last_be = pkt.last_be

            self.discontinue = pkt.discontinue

            self.data = pkt.data[4:]

            # compute byte enables
            byte_en = [0]*4

            if len(self.data) >= 1:
                byte_en += [self.first_be]
            if len(self.data) > 2:
                byte_en += [0xf] * (len(self.data)-2)
            if len(self.data) > 1:
                byte_en += [self.last_be]

            # check byte enables
            assert byte_en == pkt.byte_en

            # check parity
            if check_parity:
                assert pkt.check_parity()

        return self

    def pack_us_cc(self):
        pkt = USPcieFrame()

        if (self.fmt_type == TLP_CPL or self.fmt_type == TLP_CPL_DATA or
                self.fmt_type == TLP_CPL_LOCKED or self.fmt_type == TLP_CPL_LOCKED_DATA):
            # Requester Completion descriptor
            l = self.lower_address & 0x7f
            l |= (self.at & 3) << 8
            l |= (self.byte_count & 0x1fff) << 16
            if self.fmt_type == TLP_CPL_LOCKED or self.fmt_type == TLP_CPL_LOCKED_DATA:
                # TODO only for completions for locked read requests
                l |= 1 << 29
            # TODO request completed
            pkt.data.append(l)
            l = self.length & 0x7ff
            l |= (self.status & 0x7) << 11
            # TODO poisoned completion
            l |= int(self.requester_id) << 16
            pkt.data.append(l)
            l = (self.tag & 0xff)
            l |= int(self.completer_id) << 8
            if self.completer_id_enable: l |= 1 << 24
            l |= (self.tc & 0x7) << 25
            l |= (self.attr & 0x7) << 28
            pkt.data.append(l)

            pkt.discontinue = self.discontinue

            # payload data
            pkt.data += self.data

            # compute parity
            pkt.update_parity()
        else:
            raise Exception("Invalid packet type for interface")

        return pkt

    def unpack_us_cc(self, pkt, check_parity=False):
        self.fmt_type = TLP_CPL

        self.lower_address = pkt.data[0] & 0x7f
        self.at = (pkt.data[0] >> 8) & 3
        self.byte_count = (pkt.data[0] >> 16) & 0x1fff
        if pkt.data[0] & (1 << 29):
            self.fmt_type = TLP_CPL_LOCKED

        self.length = pkt.data[1] & 0x7ff
        if self.length > 0:
            self.fmt = FMT_3DW_DATA
        self.status = (pkt.data[1] >> 11) & 7
        self.requester_id = PcieId.from_int(pkt.data[1] >> 16)
        self.completer_id = PcieId.from_int(pkt.data[2] >> 8)
        self.completer_id_enable = pkt.data[2] >> 24 & 1 != 0
        self.tag = pkt.data[2] & 0xff
        self.tc = (pkt.data[2] >> 25) & 0x7
        self.attr = (pkt.data[2] >> 28) & 0x7

        self.discontinue = pkt.discontinue

        if self.length > 0:
            self.data = pkt.data[3:3+self.length]

        # check parity
        if check_parity:
            assert pkt.check_parity()

        return self

    def pack_us_rq(self):
        pkt = USPcieFrame()

        if (self.fmt_type == TLP_IO_READ or self.fmt_type == TLP_IO_WRITE or
                self.fmt_type == TLP_MEM_READ or self.fmt_type == TLP_MEM_READ_64 or
                self.fmt_type == TLP_MEM_WRITE or self.fmt_type == TLP_MEM_WRITE_64 or
                self.fmt_type == TLP_CFG_READ_0 or self.fmt_type == TLP_CFG_READ_1 or
                self.fmt_type == TLP_CFG_WRITE_0 or self.fmt_type == TLP_CFG_WRITE_1):
            # Completer Request descriptor
            if (self.fmt_type == TLP_IO_READ or self.fmt_type == TLP_IO_WRITE or
                    self.fmt_type == TLP_MEM_READ or self.fmt_type == TLP_MEM_READ_64 or
                    self.fmt_type == TLP_MEM_WRITE or self.fmt_type == TLP_MEM_WRITE_64):
                l = self.at & 0x3
                l |= self.address & 0xfffffffc
                pkt.data.append(l)
                l = (self.address & 0xffffffff00000000) >> 32
                pkt.data.append(l)
            elif (self.fmt_type == TLP_CFG_READ_0 or self.fmt_type == TLP_CFG_READ_1 or
                    self.fmt_type == TLP_CFG_WRITE_0 or self.fmt_type == TLP_CFG_WRITE_1):
                l = (self.register_number & 0x3ff) << 2
                pkt.data.append(l)
                pkt.data.append(0)
            l = self.length & 0x7ff
            if self.fmt_type == TLP_MEM_READ or self.fmt_type == TLP_MEM_READ_64:
                l |= REQ_MEM_READ << 11
            elif self.fmt_type == TLP_MEM_WRITE or self.fmt_type == TLP_MEM_WRITE_64:
                l |= REQ_MEM_WRITE << 11
            elif self.fmt_type == TLP_IO_READ:
                l |= REQ_IO_READ << 11
            elif self.fmt_type == TLP_IO_WRITE:
                l |= REQ_IO_WRITE << 11
            elif self.fmt_type == TLP_FETCH_ADD or self.fmt_type == TLP_FETCH_ADD_64:
                l |= REQ_MEM_FETCH_ADD << 11
            elif self.fmt_type == TLP_SWAP or self.fmt_type == TLP_SWAP_64:
                l |= REQ_MEM_SWAP << 11
            elif self.fmt_type == TLP_CAS or self.fmt_type == TLP_CAS_64:
                l |= REQ_MEM_CAS << 11
            elif self.fmt_type == TLP_MEM_READ_LOCKED or self.fmt_type == TLP_MEM_READ_LOCKED_64:
                l |= REQ_MEM_READ_LOCKED << 11
            elif self.fmt_type == TLP_CFG_READ_0:
                l |= REQ_CFG_READ_0 << 11
            elif self.fmt_type == TLP_CFG_READ_1:
                l |= REQ_CFG_READ_1 << 11
            elif self.fmt_type == TLP_CFG_WRITE_0:
                l |= REQ_CFG_WRITE_0 << 11
            elif self.fmt_type == TLP_CFG_WRITE_1:
                l |= REQ_CFG_WRITE_1 << 11
            # TODO poisoned
            l |= int(self.requester_id) << 16
            pkt.data.append(l)
            l = (self.tag & 0xff)
            l |= int(self.completer_id) << 8
            if self.requester_id_enable: l |= 1 << 24
            l |= (self.tc & 0x7) << 25
            l |= (self.attr & 0x7) << 28
            # TODO force ecrc
            pkt.data.append(l)

            pkt.first_be = self.first_be
            pkt.last_be = self.last_be

            pkt.discontinue = self.discontinue

            pkt.seq_num = self.seq_num

            # payload data
            pkt.data += self.data

            # compute parity
            pkt.update_parity()
        else:
            raise Exception("Invalid packet type for interface")

        return pkt

    def unpack_us_rq(self, pkt, check_parity=False):
        req_type = (pkt.data[2] >> 11) & 0xf

        if req_type == REQ_MEM_READ:
            self.fmt_type = TLP_MEM_READ
        elif req_type == REQ_MEM_WRITE:
            self.fmt_type = TLP_MEM_WRITE
        elif req_type == REQ_IO_READ:
            self.fmt_type = TLP_IO_READ
        elif req_type == REQ_IO_WRITE:
            self.fmt_type = TLP_IO_WRITE
        elif req_type == REQ_MEM_FETCH_ADD:
            self.fmt_type = TLP_FETCH_ADD
        elif req_type == REQ_MEM_SWAP:
            self.fmt_type = TLP_SWAP
        elif req_type == REQ_MEM_CAS:
            self.fmt_type = TLP_CAS
        elif req_type == REQ_MEM_READ_LOCKED:
            self.fmt_type = TLP_MEM_READ_LOCKED
        elif req_type == REQ_CFG_READ_0:
            self.fmt_type = TLP_CFG_READ_0
        elif req_type == REQ_CFG_READ_1:
            self.fmt_type = TLP_CFG_READ_1
        elif req_type == REQ_CFG_WRITE_0:
            self.fmt_type = TLP_CFG_WRITE_0
        elif req_type == REQ_CFG_WRITE_1:
            self.fmt_type = TLP_CFG_WRITE_1
        else:
            raise Exception("Invalid packet type")

        self.length = pkt.data[2] & 0x7ff
        # TODO poisoned
        self.requester_id = PcieId.from_int(pkt.data[2] >> 16)
        self.tag = pkt.data[3] & 0xff
        self.tc = (pkt.data[3] >> 25) & 0x7
        self.attr = (pkt.data[3] >> 28) & 0x7

        if req_type < 12:
            if req_type < 8:
                # memory, IO, or atomic operation
                self.at = pkt.data[0] & 3
                self.address = (pkt.data[1] << 32) | (pkt.data[0] & 0xfffffffc)
                if self.address > 0xffffffff:
                    if self.fmt == FMT_3DW:
                        self.fmt = FMT_4DW
                    elif self.fmt == FMT_3DW_DATA:
                        self.fmt = FMT_4DW_DATA
            else:
                self.register_number = (pkt.data[0] >> 2) & 0x3ff
            self.completer_id = PcieId.from_int(pkt.data[3] >> 8)
            self.requester_id_enable = pkt.data[3] >> 24 & 1 != 0

            self.first_be = pkt.first_be
            self.last_be = pkt.last_be

            self.discontinue = pkt.discontinue

            self.seq_num = pkt.seq_num

            self.data = pkt.data[4:]

            # check parity
            if check_parity:
                assert pkt.check_parity()
        else:
            raise Exception("TODO")

        return self

    def pack_us_rc(self):
        pkt = USPcieFrame()

        if (self.fmt_type == TLP_CPL or self.fmt_type == TLP_CPL_DATA or
                self.fmt_type == TLP_CPL_LOCKED or self.fmt_type == TLP_CPL_LOCKED_DATA):
            # Requester Completion descriptor
            l = self.lower_address & 0xfff
            l |= (self.error_code & 0xf) << 12
            l |= (self.byte_count & 0x1fff) << 16
            if self.fmt_type == TLP_CPL_LOCKED or self.fmt_type == TLP_CPL_LOCKED_DATA:
                l |= 1 << 29
            # TODO request completed
            pkt.data.append(l)
            l = self.length & 0x7ff
            l |= (self.status & 0x7) << 11
            # TODO poisoned completion
            l |= int(self.requester_id) << 16
            pkt.data.append(l)
            l = (self.tag & 0xff)
            l |= int(self.completer_id) << 8
            l |= (self.tc & 0x7) << 25
            l |= (self.attr & 0x7) << 28
            pkt.data.append(l)

            pkt.discontinue = self.discontinue

            # payload data
            pkt.data += self.data

            # compute byte enables
            pkt.byte_en = [0]*3

            first_be = (0xf << (self.lower_address&3)) & 0xf
            if self.byte_count+(self.lower_address&3) > self.length*4:
                last_be = 0xf
            else:
                last_be = 0xf >> ((4-self.byte_count-self.lower_address)&3)

            if len(self.data) == 1:
                first_be = first_be & last_be
                last_be = 0

            if len(self.data) >= 1:
                pkt.byte_en += [first_be]
            if len(self.data) > 2:
                pkt.byte_en += [0xf] * (len(self.data)-2)
            if len(self.data) > 1:
                pkt.byte_en += [last_be]

            # compute parity
            pkt.update_parity()
        else:
            raise Exception("Invalid packet type for interface")

        return pkt

    def unpack_us_rc(self, pkt, check_parity=False):
        self.fmt_type = TLP_CPL

        self.lower_address = pkt.data[0] & 0xfff
        self.error_code = (pkt.data[0] >> 12) & 0xf
        self.byte_count = (pkt.data[0] >> 16) & 0x1fff
        if pkt.data[0] & (1 << 29):
            self.fmt_type = TLP_CPL_LOCKED

        self.length = pkt.data[1] & 0x7ff
        if self.length > 0:
            self.fmt = FMT_3DW_DATA
        self.status = (pkt.data[1] >> 11) & 7
        self.requester_id = PcieId.from_int(pkt.data[1] >> 16)
        self.completer_id = PcieId.from_int(pkt.data[2] >> 8)
        self.tag = pkt.data[2] & 0xff
        self.tc = (pkt.data[2] >> 25) & 0x7
        self.attr = (pkt.data[2] >> 28) & 0x7

        self.discontinue = pkt.discontinue

        if self.length > 0:
            self.data = pkt.data[3:3+self.length]

        # compute byte enables
        byte_en = [0]*3

        first_be = (0xf << (self.lower_address&3)) & 0xf
        if self.byte_count+(self.lower_address&3) > self.length*4:
            last_be = 0xf
        else:
            last_be = 0xf >> ((4-self.byte_count-self.lower_address)&3)

        if len(self.data) == 1:
            first_be = first_be & last_be
            last_be = 0

        if len(self.data) >= 1:
            byte_en += [first_be]
        if len(self.data) > 2:
            byte_en += [0xf] * (len(self.data)-2)
        if len(self.data) > 1:
            byte_en += [last_be]

        # check byte enables
        assert byte_en == pkt.byte_en

        # check parity
        if check_parity:
            assert pkt.check_parity()

        return self

    def __eq__(self, other):
        if isinstance(other, TLP_us):
            return (
                    self.data == other.data and
                    self.fmt == other.fmt and
                    self.type == other.type and
                    self.tc == other.tc and
                    self.td == other.td and
                    self.ep == other.ep and
                    self.attr == other.attr and
                    self.at == other.at and
                    self.length == other.length and
                    self.completer_id == other.completer_id and
                    self.status == other.status and
                    self.bcm == other.bcm and
                    self.byte_count == other.byte_count and
                    self.requester_id == other.requester_id and
                    self.dest_id == other.dest_id and
                    self.tag == other.tag and
                    self.first_be == other.first_be and
                    self.last_be == other.last_be and
                    self.lower_address == other.lower_address and
                    self.address == other.address and
                    self.register_number == other.register_number
                )
        return False

    def __repr__(self):
        return (
                ('TLP_us(data=[%s], ' % ', '.join(hex(x) for x in self.data)) +
                ('fmt=0x%x, ' % self.fmt) +
                ('type=0x%x, ' % self.type) +
                ('tc=0x%x, ' % self.tc) +
                ('th=0x%x, ' % self.th) +
                ('td=0x%x, ' % self.td) +
                ('ep=0x%x, ' % self.ep) +
                ('attr=0x%x, ' % self.attr) +
                ('at=0x%x, ' % self.at) +
                ('length=0x%x, ' % self.length) +
                ('completer_id=%s, ' % repr(self.completer_id)) +
                ('status=0x%x, ' % self.status) +
                ('bcm=0x%x, ' % self.bcm) +
                ('byte_count=0x%x, ' % self.byte_count) +
                ('requester_id=%s, ' % repr(self.requester_id)) +
                ('dest_id=%s, ' % repr(self.dest_id)) +
                ('tag=0x%x, ' % self.tag) +
                ('first_be=0x%x, ' % self.first_be) +
                ('last_be=0x%x, ' % self.last_be) +
                ('lower_address=0x%x, ' % self.lower_address) +
                ('address=0x%x, ' % self.address) +
                ('register_number=0x%x)' % self.register_number)
            )


class CQSource(object):
    def __init__(self):
        self.active = False
        self.has_logic = False
        self.queue = []

    def send(self, frame):
        self.queue.append(USPcieFrame(frame))

    def count(self):
        return len(self.queue)

    def empty(self):
        return not self.queue

    def create_logic(self,
                clk,
                rst,
                tdata=None,
                tkeep=Signal(bool(True)),
                tvalid=Signal(bool(False)),
                tready=Signal(bool(True)),
                tlast=Signal(bool(False)),
                tuser=Signal(intbv(0)),
                pause=0,
                name=None
            ):

        assert len(tdata) in [64, 128, 256, 512]
        assert len(tkeep)*32 == len(tdata)

        if len(tdata) == 512:
            assert len(tuser) == 183
        else:
            assert len(tdata) in [64, 128, 256]
            assert len(tuser) in [85, 88]

        assert not self.has_logic

        self.has_logic = True

        @instance
        def logic():
            frame = USPcieFrame()
            data = []
            byte_en = []
            parity = []
            self.active = False
            first = True

            while True:
                yield clk.posedge, rst.posedge

                if rst:
                    data = []
                    byte_en = []
                    parity = []
                    self.active = False
                    tdata.next = 0
                    tkeep.next = 0
                    tuser.next = 0
                    tvalid.next = False
                    tlast.next = False
                    first = True
                else:
                    tvalid.next = self.active and (tvalid or not pause)
                    if tready and tvalid:
                        tvalid.next = False
                        self.active = False
                    if not data and self.queue:
                        frame = self.queue.pop(0)
                        data = list(frame.data)
                        byte_en = list(frame.byte_en)
                        parity = list(frame.parity)
                        if name is not None:
                            print("[%s] Sending frame %s" % (name, repr(frame)))
                        first = True
                    if data and not self.active:
                        d = 0
                        k = 0
                        u = 0

                        if len(tdata) == 512:
                            if first:
                                u |= (frame.first_be & 0xf)
                                u |= (frame.last_be & 0xf) << 8
                                u |= 0b01 << 80 # is_sop
                                u |= 0b00 << 82 # is_sop0_ptr

                            if frame.discontinue:
                                u |= 1 << 96 # discontinue

                            last_lane = 0

                            for i in range(len(tkeep)):
                                if data:
                                    d |= data.pop(0) << i*32
                                    k |= 1 << i
                                    u |= byte_en.pop(0) << i*4+16
                                    u |= parity.pop(0) << i*4+119
                                    last_lane = i
                                else:
                                    u |= 0xf << i*4+119

                            if not data:
                                u |= 0b01 << 86 # is_eop
                                u |= (last_lane & 0xf) << 88 # is_eop0_ptr
                        else:
                            if first:
                                u |= (frame.first_be & 0xf)
                                u |= (frame.last_be & 0xf) << 4
                                u |= 1 << 40 # sop

                            if frame.discontinue:
                                u |= 1 << 41 # discontinue

                            for i in range(len(tkeep)):
                                if data:
                                    d |= data.pop(0) << i*32
                                    k |= 1 << i
                                    u |= byte_en.pop(0) << i*4+8
                                    u |= parity.pop(0) << i*4+53
                                else:
                                    u |= 0xf << i*4+53

                        tdata.next = d
                        tkeep.next = k
                        tuser.next = u
                        tvalid.next = not pause
                        tlast.next = len(data) == 0
                        self.active = True
                        first = False

        return instances()


class CQSink(object):
    def __init__(self):
        self.has_logic = False
        self.queue = []
        self.read_queue = []
        self.sync = Signal(intbv(0))

    def recv(self):
        if self.queue:
            return self.queue.pop(0)
        return None

    def count(self):
        return len(self.queue)

    def empty(self):
        return not self.queue

    def wait(self, timeout=0):
        if self.queue:
            return
        if timeout:
            yield self.sync, delay(timeout)
        else:
            yield self.sync

    def create_logic(self,
                clk,
                rst,
                tdata=None,
                tkeep=Signal(bool(True)),
                tvalid=Signal(bool(False)),
                tready=Signal(bool(True)),
                tlast=Signal(bool(True)),
                tuser=Signal(intbv(0)),
                pause=0,
                name=None
            ):

        assert len(tdata) in [64, 128, 256, 512]
        assert len(tkeep)*32 == len(tdata)

        if len(tdata) == 512:
            assert len(tuser) == 183
        else:
            assert len(tdata) in [64, 128, 256]
            assert len(tuser) in [85, 88]

        assert not self.has_logic

        self.has_logic = True

        tready_int = Signal(bool(False))
        tvalid_int = Signal(bool(False))

        @always_comb
        def pause_logic():
            tready.next = tready_int and not pause
            tvalid_int.next = tvalid and not pause

        @instance
        def logic():
            frame = USPcieFrame()
            first = True

            while True:
                yield clk.posedge, rst.posedge

                if rst:
                    tready_int.next = False
                    frame = USPcieFrame()
                    first = True
                else:
                    tready_int.next = True

                    if tvalid_int:
                        # zero tkeep not allowed
                        assert int(tkeep) != 0
                        # tkeep must be contiguous
                        # i.e. 0b00011110 allowed, but 0b00011010 not allowed
                        b = int(tkeep)
                        while b & 1 == 0:
                            b = b >> 1
                        while b & 1 == 1:
                            b = b >> 1
                        assert b == 0
                        # tkeep must not have gaps across cycles
                        if not first:
                            # not first cycle; lowest bit must be set
                            assert int(tkeep) & 1
                        if not tlast:
                            # not last cycle; highest bit must be set
                            assert int(tkeep) & (1 << len(tkeep)-1)

                        d = int(tdata)
                        u = int(tuser)

                        if len(tdata) == 512:
                            if first:
                                frame.first_be = u & 0xf
                                frame.last_be = (u >> 8) & 0xf

                            if tuser & (1 << 96):
                                frame.discontinue = True

                            last_lane = 0

                            for i in range(len(tkeep)):
                                if tkeep & (1 << i):
                                    frame.data.append((d >> (i*32)) & 0xffffffff)
                                    frame.byte_en.append((u >> (i*4+16)) & 0xf)
                                    frame.parity.append((u >> (i*4+119)) & 0xf)
                                    last_lane = i
                        else:
                            if first:
                                frame.first_be = u & 0xf
                                frame.last_be = (u >> 4) & 0xf

                            if tuser & (1 << 41):
                                frame.discontinue = True

                            for i in range(len(tkeep)):
                                if tkeep & (1 << i):
                                    frame.data.append((d >> (i*32)) & 0xffffffff)
                                    frame.byte_en.append((u >> (i*4+8)) & 0xf)
                                    frame.parity.append((u >> (i*4+53)) & 0xf)

                        first = False
                        if tlast:
                            self.queue.append(frame)
                            self.sync.next = not self.sync
                            if name is not None:
                                print("[%s] Got frame %s" % (name, repr(frame)))
                            frame = USPcieFrame()
                            first = True

        return instances()


class CCSource(object):
    def __init__(self):
        self.active = False
        self.has_logic = False
        self.queue = []

    def send(self, frame):
        self.queue.append(USPcieFrame(frame))

    def count(self):
        return len(self.queue)

    def empty(self):
        return not self.queue

    def create_logic(self,
                clk,
                rst,
                tdata=None,
                tkeep=Signal(bool(True)),
                tvalid=Signal(bool(False)),
                tready=Signal(bool(True)),
                tlast=Signal(bool(False)),
                tuser=Signal(intbv(0)),
                pause=0,
                name=None
            ):

        assert len(tdata) in [64, 128, 256, 512]
        assert len(tkeep)*32 == len(tdata)

        if len(tdata) == 512:
            assert len(tuser) == 81
        else:
            assert len(tdata) in [64, 128, 256]
            assert len(tuser) == 33

        assert not self.has_logic

        self.has_logic = True

        @instance
        def logic():
            frame = USPcieFrame()
            data = []
            parity = []
            self.active = False
            first = True

            while True:
                yield clk.posedge, rst.posedge

                if rst:
                    data = []
                    parity = []
                    self.active = False
                    tdata.next = 0
                    tkeep.next = 0
                    tuser.next = 0
                    tvalid.next = False
                    tlast.next = False
                    first = True
                else:
                    tvalid.next = self.active and (tvalid or not pause)
                    if tready and tvalid:
                        tvalid.next = False
                        self.active = False
                    if not data and self.queue:
                        frame = self.queue.pop(0)
                        data = list(frame.data)
                        parity = list(frame.parity)
                        if name is not None:
                            print("[%s] Sending frame %s" % (name, repr(frame)))
                        first = True
                    if data and not self.active:
                        d = 0
                        k = 0
                        u = 0

                        if len(tdata) == 512:
                            if first:
                                u |= 0b01 << 0 # is_sop
                                u |= 0b00 << 2 # is_sop0_ptr

                            if frame.discontinue:
                                u |= 1 << 16 # discontinue

                            last_lane = 0

                            for i in range(len(tkeep)):
                                if data:
                                    d |= data.pop(0) << i*32
                                    k |= 1 << i
                                    u |= parity.pop(0) << i*4+17
                                    last_lane = i
                                else:
                                    u |= 0xf << i*4+17

                            if not data:
                                u |= 0b01 << 6 # is_eop
                                u |= (last_lane & 0xf) << 8 # is_eop0_ptr
                        else:
                            if frame.discontinue:
                                u |= 1 # discontinue

                            for i in range(len(tkeep)):
                                if data:
                                    d |= data.pop(0) << i*32
                                    k |= 1 << i
                                    u |= parity.pop(0) << i*4+1
                                else:
                                    u |= 0xf << i*4+1

                        tdata.next = d
                        tkeep.next = k
                        tuser.next = u
                        tvalid.next = not pause
                        tlast.next = len(data) == 0
                        self.active = True
                        first = False

        return instances()


class CCSink(object):
    def __init__(self):
        self.has_logic = False
        self.queue = []
        self.read_queue = []
        self.sync = Signal(intbv(0))

    def recv(self):
        if self.queue:
            return self.queue.pop(0)
        return None

    def count(self):
        return len(self.queue)

    def empty(self):
        return not self.queue

    def wait(self, timeout=0):
        if self.queue:
            return
        if timeout:
            yield self.sync, delay(timeout)
        else:
            yield self.sync

    def create_logic(self,
                clk,
                rst,
                tdata=None,
                tkeep=Signal(bool(True)),
                tvalid=Signal(bool(False)),
                tready=Signal(bool(True)),
                tlast=Signal(bool(True)),
                tuser=Signal(intbv(0)),
                pause=0,
                name=None
            ):

        assert len(tdata) in [64, 128, 256, 512]
        assert len(tkeep)*32 == len(tdata)

        if len(tdata) == 512:
            assert len(tuser) == 81
        else:
            assert len(tdata) in [64, 128, 256]
            assert len(tuser) == 33

        assert not self.has_logic

        self.has_logic = True

        tready_int = Signal(bool(False))
        tvalid_int = Signal(bool(False))

        @always_comb
        def pause_logic():
            tready.next = tready_int and not pause
            tvalid_int.next = tvalid and not pause

        @instance
        def logic():
            frame = USPcieFrame()
            first = True

            while True:
                yield clk.posedge, rst.posedge

                if rst:
                    tready_int.next = False
                    frame = USPcieFrame()
                    first = True
                else:
                    tready_int.next = True

                    if tvalid_int:
                        # zero tkeep not allowed
                        assert int(tkeep) != 0
                        # tkeep must be contiguous
                        # i.e. 0b00011110 allowed, but 0b00011010 not allowed
                        b = int(tkeep)
                        while b & 1 == 0:
                            b = b >> 1
                        while b & 1 == 1:
                            b = b >> 1
                        assert b == 0
                        # tkeep must not have gaps across cycles
                        if not first:
                            # not first cycle; lowest bit must be set
                            assert int(tkeep) & 1
                        if not tlast:
                            # not last cycle; highest bit must be set
                            assert int(tkeep) & (1 << len(tkeep)-1)

                        d = int(tdata)
                        u = int(tuser)

                        if len(tdata) == 512:
                            if u & (1 << 16):
                                frame.discontinue = True

                            last_lane = 0

                            for i in range(len(tkeep)):
                                if tkeep & (1 << i):
                                    frame.data.append((d >> (i*32)) & 0xffffffff)
                                    frame.parity.append((u >> (i*4+17)) & 0xf)
                                    last_lane = i
                        else:
                            if u & 1:
                                frame.discontinue = True

                            for i in range(len(tkeep)):
                                if tkeep & (1 << i):
                                    frame.data.append((d >> (i*32)) & 0xffffffff)
                                    frame.parity.append((u >> (i*4+1)) & 0xf)

                        first = False
                        if tlast:
                            self.queue.append(frame)
                            self.sync.next = not self.sync
                            if name is not None:
                                print("[%s] Got frame %s" % (name, repr(frame)))
                            frame = USPcieFrame()
                            first = True

        return instances()


class RQSource(object):
    def __init__(self):
        self.active = False
        self.has_logic = False
        self.queue = []

    def send(self, frame):
        self.queue.append(USPcieFrame(frame))

    def count(self):
        return len(self.queue)

    def empty(self):
        return not self.queue

    def create_logic(self,
                clk,
                rst,
                tdata=None,
                tkeep=Signal(bool(True)),
                tvalid=Signal(bool(False)),
                tready=Signal(bool(True)),
                tlast=Signal(bool(False)),
                tuser=Signal(intbv(0)),
                pause=0,
                name=None
            ):

        assert len(tdata) in [64, 128, 256, 512]
        assert len(tkeep)*32 == len(tdata)

        if len(tdata) == 512:
            assert len(tuser) == 137
        else:
            assert len(tdata) in [64, 128, 256]
            assert len(tuser) in [60, 62]

        assert not self.has_logic

        self.has_logic = True

        @instance
        def logic():
            frame = USPcieFrame()
            data = []
            parity = []
            self.active = False
            first = True

            while True:
                yield clk.posedge, rst.posedge

                if rst:
                    data = []
                    parity = []
                    self.active = False
                    tdata.next = 0
                    tkeep.next = 0
                    tuser.next = 0
                    tvalid.next = False
                    tlast.next = False
                    first = True
                else:
                    tvalid.next = self.active and (tvalid or not pause)
                    if tready and tvalid:
                        tvalid.next = False
                        self.active = False
                    if not data and self.queue:
                        frame = self.queue.pop(0)
                        data = list(frame.data)
                        parity = list(frame.parity)
                        if name is not None:
                            print("[%s] Sending frame %s" % (name, repr(frame)))
                        first = True
                    if data and not self.active:
                        d = 0
                        k = 0
                        u = 0

                        if len(tdata) == 512:
                            if first:
                                u |= (frame.first_be & 0xf)
                                u |= (frame.last_be & 0xf) << 8
                                u |= 0b01 << 20 # is_sop
                                u |= 0b00 << 22 # is_sop0_ptr

                            if frame.discontinue:
                                u |= 1 << 36 # discontinue

                            u |= (frame.seq_num & 0x3f) << 61

                            last_lane = 0

                            for i in range(len(tkeep)):
                                if data:
                                    d |= data.pop(0) << i*32
                                    k |= 1 << i
                                    u |= parity.pop(0) << i*4+73
                                    last_lane = i
                                else:
                                    u |= 0xf << i*4+73

                            if not data:
                                u |= 0b01 << 26 # is_eop
                                u |= (last_lane & 0xf) << 28 # is_eop0_ptr
                        else:
                            if first:
                                u |= (frame.first_be & 0xf)
                                u |= (frame.last_be & 0xf) << 4

                            if frame.discontinue:
                                u |= 1 << 11 # discontinue

                            u |= (frame.seq_num & 0xf) << 24

                            if len(tuser) == 62:
                                u |= ((frame.seq_num >> 4) & 0x3) << 60

                            for i in range(len(tkeep)):
                                if data:
                                    d |= data.pop(0) << i*32
                                    k |= 1 << i
                                    u |= parity.pop(0) << i*4+28
                                else:
                                    u |= 0xf << i*4+28

                            # TODO seq_num
                            # TODO tph

                        tdata.next = d
                        tkeep.next = k
                        tuser.next = u
                        tvalid.next = not pause
                        tlast.next = len(data) == 0
                        self.active = True
                        first = False

        return instances()


class RQSink(object):
    def __init__(self):
        self.has_logic = False
        self.queue = []
        self.read_queue = []
        self.sync = Signal(intbv(0))

    def recv(self):
        if self.queue:
            return self.queue.pop(0)
        return None

    def count(self):
        return len(self.queue)

    def empty(self):
        return not self.queue

    def wait(self, timeout=0):
        if self.queue:
            return
        if timeout:
            yield self.sync, delay(timeout)
        else:
            yield self.sync

    def create_logic(self,
                clk,
                rst,
                tdata=None,
                tkeep=Signal(bool(True)),
                tvalid=Signal(bool(False)),
                tready=Signal(bool(True)),
                tlast=Signal(bool(True)),
                tuser=Signal(intbv(0)),
                pause=0,
                name=None
            ):

        assert len(tdata) in [64, 128, 256, 512]
        assert len(tkeep)*32 == len(tdata)

        if len(tdata) == 512:
            assert len(tuser) == 137
        else:
            assert len(tdata) in [64, 128, 256]
            assert len(tuser) in [60, 62]

        assert not self.has_logic

        self.has_logic = True

        tready_int = Signal(bool(False))
        tvalid_int = Signal(bool(False))

        @always_comb
        def pause_logic():
            tready.next = tready_int and not pause
            tvalid_int.next = tvalid and not pause

        @instance
        def logic():
            frame = USPcieFrame()
            first = True

            while True:
                yield clk.posedge, rst.posedge

                if rst:
                    tready_int.next = False
                    frame = USPcieFrame()
                    first = True
                else:
                    tready_int.next = True

                    if tvalid_int:
                        # zero tkeep not allowed
                        assert int(tkeep) != 0
                        # tkeep must be contiguous
                        # i.e. 0b00011110 allowed, but 0b00011010 not allowed
                        b = int(tkeep)
                        while b & 1 == 0:
                            b = b >> 1
                        while b & 1 == 1:
                            b = b >> 1
                        assert b == 0
                        # tkeep must not have gaps across cycles
                        if not first:
                            # not first cycle; lowest bit must be set
                            assert int(tkeep) & 1
                        if not tlast:
                            # not last cycle; highest bit must be set
                            assert int(tkeep) & (1 << len(tkeep)-1)

                        d = int(tdata)
                        u = int(tuser)

                        if len(tdata) == 512:
                            if first:
                                frame.first_be = u & 0xf
                                frame.last_be = (u >> 8) & 0xf

                            if u & (1 << 36):
                                frame.discontinue = True

                            frame.seq_num = (u >> 61) & 0x3f

                            last_lane = 0

                            for i in range(len(tkeep)):
                                if tkeep & (1 << i):
                                    frame.data.append((d >> (i*32)) & 0xffffffff)
                                    frame.parity.append((u >> (i*4+73)) & 0xf)
                                    last_lane = i
                        else:
                            if first:
                                frame.first_be = u & 0xf
                                frame.last_be = (u >> 4) & 0xf

                            if u & (1 << 11):
                                frame.discontinue = True

                            frame.seq_num = (u >> 24) & 0xf

                            if len(tuser) == 62:
                                frame.seq_num |= ((u >> 60) & 0x3) << 4

                            for i in range(len(tkeep)):
                                if tkeep & (1 << i):
                                    frame.data.append((d >> (i*32)) & 0xffffffff)
                                    frame.parity.append((u >> (i*4+28)) & 0xf)

                        first = False
                        if tlast:
                            self.queue.append(frame)
                            self.sync.next = not self.sync
                            if name is not None:
                                print("[%s] Got frame %s" % (name, repr(frame)))
                            frame = USPcieFrame()
                            first = True

        return instances()


class RCSource(object):
    def __init__(self):
        self.active = False
        self.has_logic = False
        self.queue = []

    def send(self, frame):
        self.queue.append(USPcieFrame(frame))

    def count(self):
        return len(self.queue)

    def empty(self):
        return not self.queue

    def create_logic(self,
                clk,
                rst,
                tdata=None,
                tkeep=Signal(bool(True)),
                tvalid=Signal(bool(False)),
                tready=Signal(bool(True)),
                tlast=Signal(bool(False)),
                tuser=Signal(intbv(0)),
                pause=0,
                name=None
            ):

        assert len(tdata) in [64, 128, 256, 512]
        assert len(tkeep)*32 == len(tdata)

        if len(tdata) == 512:
            assert len(tuser) == 161
        else:
            assert len(tdata) in [64, 128, 256]
            assert len(tuser) == 75

        assert not self.has_logic

        self.has_logic = True

        @instance
        def logic():
            frame = USPcieFrame()
            data = []
            byte_en = []
            parity = []
            self.active = False
            first = True

            while True:
                yield clk.posedge, rst.posedge

                if rst:
                    data = []
                    byte_en = []
                    parity = []
                    self.active = False
                    tdata.next = 0
                    tkeep.next = 0
                    tuser.next = 0
                    tvalid.next = False
                    tlast.next = False
                    first = True
                else:
                    tvalid.next = self.active and (tvalid or not pause)
                    if tready and tvalid:
                        tvalid.next = False
                        self.active = False
                    if not data and self.queue:
                        frame = self.queue.pop(0)
                        data = list(frame.data)
                        byte_en = list(frame.byte_en)
                        parity = list(frame.parity)
                        if name is not None:
                            print("[%s] Sending frame %s" % (name, repr(frame)))
                        first = True
                    if data and not self.active:
                        d = 0
                        k = 0
                        u = 0

                        if len(tdata) == 512:
                            if first:
                                u |= 0b0001 << 64 # is_sop
                                u |= 0b00 << 68 # is_sop0_ptr

                            if frame.discontinue:
                                u |= 1 << 96 # discontinue

                            last_lane = 0

                            for i in range(len(tkeep)):
                                if data:
                                    d |= data.pop(0) << i*32
                                    k |= 1 << i
                                    u |= byte_en.pop(0) << i*4
                                    u |= parity.pop(0) << i*4+97
                                    last_lane = i
                                else:
                                    u |= 0xf << i*4+97

                            if not data:
                                u |= 0b0001 << 76 # is_eop
                                u |= last_lane << 80 # is_eop0_ptr
                        else:
                            if first:
                                u |= 1 << 32 # is_sof_0

                            if frame.discontinue:
                                u |= 1 << 42 # discontinue

                            last_lane = 0

                            for i in range(len(tkeep)):
                                if data:
                                    d |= data.pop(0) << i*32
                                    k |= 1 << i
                                    u |= byte_en.pop(0) << i*4
                                    u |= parity.pop(0) << i*4+43
                                    last_lane = i
                                else:
                                    u |= 0xf << i*4+43

                            if not data:
                                u |= (1 | last_lane << 1) << 34 # is_eof_0

                        tdata.next = d
                        tkeep.next = k
                        tuser.next = u
                        tvalid.next = not pause
                        tlast.next = len(data) == 0
                        self.active = True
                        first = False

        return instances()


class RCSink(object):
    def __init__(self):
        self.has_logic = False
        self.queue = []
        self.read_queue = []
        self.sync = Signal(intbv(0))

    def recv(self):
        if self.queue:
            return self.queue.pop(0)
        return None

    def count(self):
        return len(self.queue)

    def empty(self):
        return not self.queue

    def wait(self, timeout=0):
        if self.queue:
            return
        if timeout:
            yield self.sync, delay(timeout)
        else:
            yield self.sync

    def create_logic(self,
                clk,
                rst,
                tdata=None,
                tkeep=Signal(bool(True)),
                tvalid=Signal(bool(False)),
                tready=Signal(bool(True)),
                tlast=Signal(bool(True)),
                tuser=Signal(intbv(0)),
                pause=0,
                name=None
            ):

        assert len(tdata) in [64, 128, 256, 512]
        assert len(tkeep)*32 == len(tdata)

        if len(tdata) == 512:
            assert len(tuser) == 161
        else:
            assert len(tdata) in [64, 128, 256]
            assert len(tuser) == 75

        assert not self.has_logic

        self.has_logic = True

        tready_int = Signal(bool(False))
        tvalid_int = Signal(bool(False))

        @always_comb
        def pause_logic():
            tready.next = tready_int and not pause
            tvalid_int.next = tvalid and not pause

        @instance
        def logic():
            frame = USPcieFrame()
            first = True

            while True:
                yield clk.posedge, rst.posedge

                if rst:
                    tready_int.next = False
                    frame = USPcieFrame()
                    first = True
                else:
                    tready_int.next = True

                    if tvalid_int:
                        # zero tkeep not allowed
                        assert int(tkeep) != 0
                        # tkeep must be contiguous
                        # i.e. 0b00011110 allowed, but 0b00011010 not allowed
                        b = int(tkeep)
                        while b & 1 == 0:
                            b = b >> 1
                        while b & 1 == 1:
                            b = b >> 1
                        assert b == 0
                        # tkeep must not have gaps across cycles
                        if not first:
                            # not first cycle; lowest bit must be set
                            assert int(tkeep) & 1
                        if not tlast:
                            # not last cycle; highest bit must be set
                            assert int(tkeep) & (1 << len(tkeep)-1)

                        d = int(tdata)
                        u = int(tuser)

                        if len(tdata) == 512:
                            if u & (1 << 96):
                                frame.discontinue = True

                            last_lane = 0

                            for i in range(len(tkeep)):
                                if tkeep & (1 << i):
                                    frame.data.append((d >> (i*32)) & 0xffffffff)
                                    frame.byte_en.append((u >> (i*4)) & 0xf)
                                    frame.parity.append((u >> (i*4+97)) & 0xf)
                                    last_lane = i
                        else:
                            if u & (1 << 42):
                                frame.discontinue = True

                            last_lane = 0

                            for i in range(len(tkeep)):
                                if tkeep & (1 << i):
                                    frame.data.append((d >> (i*32)) & 0xffffffff)
                                    frame.byte_en.append((u >> (i*4)) & 0xf)
                                    frame.parity.append((u >> (i*4+43)) & 0xf)
                                    last_lane = i

                        first = False
                        if tlast:
                            self.queue.append(frame)
                            self.sync.next = not self.sync
                            if name is not None:
                                print("[%s] Got frame %s" % (name, repr(frame)))
                            frame = USPcieFrame()
                            first = True

        return instances()


class UltrascalePCIeFunction(Endpoint, MSICapability, MSIXCapability):
    def __init__(self):
        super(UltrascalePCIeFunction, self).__init__()

        self.msi_64bit_address_capable = 1
        self.msi_per_vector_mask_capable = 0

        self.register_capability(PM_CAP_ID, offset=0x20)
        self.register_capability(MSI_CAP_ID, offset=0x24)
        self.register_capability(MSIX_CAP_ID, offset=0x2c)
        self.register_capability(PCIE_CAP_ID, offset=0x30)


class UltrascalePCIe(Device):
    def __init__(self):
        super(UltrascalePCIe, self).__init__()

        self.has_logic = False

        self.default_function = UltrascalePCIeFunction

        self.dw = 256

        # configuration options
        self.pcie_generation = 3
        self.pcie_link_width = 8
        self.user_clk_frequency = 250e6
        self.alignment = "dword"
        self.straddle = False
        self.enable_pf1 = False
        self.enable_client_tag = True
        self.enable_extended_tag = False
        self.enable_parity = False
        self.enable_rx_msg_interface = False
        self.enable_sriov = False
        self.enable_extended_configuration = False

        self.enable_pf0_msi = False
        self.enable_pf1_msi = False

        self.cq_queue = []
        self.cq_np_queue = []
        self.cq_np_req_count = 0
        self.rc_queue = []
        self.msg_queue = []

        self.config_space_enable = False

        self.cq_source = CQSource()
        self.cc_sink = CCSink()
        self.rq_sink = RQSink()
        self.rc_source = RCSource()

        self.rq_seq_num = []

        self.make_function()


    def upstream_recv(self, tlp):
        # logging
        print("[%s] Got downstream TLP: %s" % (highlight(self.get_desc()), repr(tlp)))
        if tlp.fmt_type == TLP_CFG_READ_0 or tlp.fmt_type == TLP_CFG_WRITE_0:
            # config type 0

            if not self.config_space_enable:
                print("Configuraion space disabled")

                cpl = TLP()
                cpl.set_crs_completion(tlp, (self.bus_num, self.device_num, 0))
                # logging
                print("[%s] CRS Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
                yield from self.upstream_send(cpl)
                return
            elif tlp.dest_id.device == self.device_num:
                # capture address information
                self.bus_num = tlp.dest_id.bus

                for f in self.functions:
                    f.bus_num = self.bus_num

                # pass TLP to function
                for f in self.functions:
                    if f.function_num == tlp.dest_id.function:
                        yield from f.upstream_recv(tlp)
                        return

                #raise Exception("Function not found")
                print("Function not found")
            else:
                print("Device number mismatch")
            
            # Unsupported request
            cpl = TLP()
            cpl.set_ur_completion(tlp, (self.bus_num, self.device_num, 0))
            # logging
            print("[%s] UR Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
            yield from self.upstream_send(cpl)
        elif (tlp.fmt_type == TLP_CPL or tlp.fmt_type == TLP_CPL_DATA or
                tlp.fmt_type == TLP_CPL_LOCKED or tlp.fmt_type == TLP_CPL_LOCKED_DATA):
            # Completion

            if tlp.requester_id.bus == self.bus_num and tlp.requester_id.device == self.device_num:
                for f in self.functions:
                    if f.function_num == tlp.requester_id.function:

                        tlp = TLP_us(tlp)

                        tlp.error_code = RC_ERROR_NORMAL_TERMINATION

                        if tlp.status != CPL_STATUS_SC:
                            tlp.error = RC_ERROR_BAD_STATUS

                        self.rc_queue.append(tlp)

                        return

                print("Function not found")
            else:
                print("Bus/device number mismatch")
        elif (tlp.fmt_type == TLP_IO_READ or tlp.fmt_type == TLP_IO_WRITE):
            # IO read/write

            for f in self.functions:
                bar = f.match_bar(tlp.address, True)
                if len(bar) == 1:

                    tlp = TLP_us(tlp)
                    tlp.bar_id = bar[0][0]
                    tlp.bar_aperture = int(math.log2((~self.functions[0].bar_mask[bar[0][0]]&0xffffffff)+1))
                    tlp.completer_id = PcieId(self.bus_num, self.device_num, f.function_num)
                    self.cq_queue.append(tlp)

                    return

            print("IO request did not match any BARs")

            # Unsupported request
            cpl = TLP()
            cpl.set_ur_completion(tlp, (self.bus_num, self.device_num, 0))
            # logging
            print("[%s] UR Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
            yield from self.upstream_send(cpl)
        elif (tlp.fmt_type == TLP_MEM_READ or tlp.fmt_type == TLP_MEM_READ_64 or
                tlp.fmt_type == TLP_MEM_WRITE or tlp.fmt_type == TLP_MEM_WRITE_64):
            # Memory read/write

            for f in self.functions:
                bar = f.match_bar(tlp.address)
                if len(bar) == 1:

                    tlp = TLP_us(tlp)
                    tlp.bar_id = bar[0][0]
                    if self.functions[0].bar[bar[0][0]] & 4:
                        tlp.bar_aperture = int(math.log2((~(self.functions[0].bar_mask[bar[0][0]] | (self.functions[0].bar_mask[bar[0][0]+1]<<32))&0xffffffffffffffff)+1))
                    else:
                        tlp.bar_aperture = int(math.log2((~self.functions[0].bar_mask[bar[0][0]]&0xffffffff)+1))
                    tlp.completer_id = PcieId(self.bus_num, self.device_num, f.function_num)
                    self.cq_queue.append(tlp)

                    return

            print("Memory request did not match any BARs")

            if tlp.fmt_type == TLP_MEM_READ or tlp.fmt_type == TLP_MEM_READ_64:
                # Unsupported request
                cpl = TLP()
                cpl.set_ur_completion(tlp, PcieId(self.bus_num, self.device_num, 0))
                # logging
                print("[%s] UR Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
                yield from self.upstream_send(cpl)
        else:
            raise Exception("TODO")

    def create_logic(self,
                # Completer reQuest Interface
                m_axis_cq_tdata=None,
                m_axis_cq_tuser=None,
                m_axis_cq_tlast=None,
                m_axis_cq_tkeep=None,
                m_axis_cq_tvalid=None,
                m_axis_cq_tready=None,
                pcie_cq_np_req=Signal(bool(1)),
                pcie_cq_np_req_count=Signal(intbv(0)[6:]),

                # Completer Completion Interface
                s_axis_cc_tdata=None,
                s_axis_cc_tuser=None,
                s_axis_cc_tlast=None,
                s_axis_cc_tkeep=None,
                s_axis_cc_tvalid=None,
                s_axis_cc_tready=None,

                # Requester reQuest Interface
                s_axis_rq_tdata=None,
                s_axis_rq_tuser=None,
                s_axis_rq_tlast=None,
                s_axis_rq_tkeep=None,
                s_axis_rq_tvalid=None,
                s_axis_rq_tready=None,
                pcie_rq_seq_num=Signal(intbv(0)[4:]),
                pcie_rq_seq_num_vld=Signal(bool(0)),
                pcie_rq_tag=Signal(intbv(0)[6:]),
                pcie_rq_tag_av=Signal(intbv(0)[2:]),
                pcie_rq_tag_vld=Signal(bool(0)),

                # Requester Completion Interface
                m_axis_rc_tdata=None,
                m_axis_rc_tuser=None,
                m_axis_rc_tlast=None,
                m_axis_rc_tkeep=None,
                m_axis_rc_tvalid=None,
                m_axis_rc_tready=None,

                # Transmit Flow Control Interface
                pcie_tfc_nph_av=Signal(intbv(0)[2:]),
                pcie_tfc_npd_av=Signal(intbv(0)[2:]),

                # Configuration Management Interface
                cfg_mgmt_addr=Signal(intbv(0)[19:]),
                cfg_mgmt_write=Signal(bool(0)),
                cfg_mgmt_write_data=Signal(intbv(0)[32:]),
                cfg_mgmt_byte_enable=Signal(intbv(0)[4:]),
                cfg_mgmt_read=Signal(bool(0)),
                cfg_mgmt_read_data=Signal(intbv(0)[32:]),
                cfg_mgmt_read_write_done=Signal(bool(0)),
                cfg_mgmt_type1_cfg_reg_access=Signal(bool(0)),

                # Configuration Status Interface
                cfg_phy_link_down=Signal(bool(0)),
                cfg_phy_link_status=Signal(intbv(0)[2:]),
                cfg_negotiated_width=Signal(intbv(0)[4:]),
                cfg_current_speed=Signal(intbv(0)[3:]),
                cfg_max_payload=Signal(intbv(0)[3:]),
                cfg_max_read_req=Signal(intbv(0)[3:]),
                cfg_function_status=Signal(intbv(0)[8:]),
                cfg_vf_status=Signal(intbv(0)[12:]),
                cfg_function_power_state=Signal(intbv(0)[6:]),
                cfg_vf_power_state=Signal(intbv(0)[18:]),
                cfg_link_power_state=Signal(intbv(0)[2:]),
                cfg_err_cor_out=Signal(bool(0)),
                cfg_err_nonfatal_out=Signal(bool(0)),
                cfg_err_fatal_out=Signal(bool(0)),
                cfg_ltr_enable=Signal(bool(0)),
                cfg_ltssm_state=Signal(intbv(0)[6:]),
                cfg_rcb_status=Signal(intbv(0)[2:]),
                cfg_dpa_substate_change=Signal(intbv(0)[2:]),
                cfg_obff_enable=Signal(intbv(0)[2:]),
                cfg_pl_status_change=Signal(bool(0)),
                cfg_tph_requester_enable=Signal(intbv(0)[2:]),
                cfg_tph_st_mode=Signal(intbv(0)[6:]),
                cfg_vf_tph_requester_enable=Signal(intbv(0)[6:]),
                cfg_vf_tph_st_mode=Signal(intbv(0)[18:]),

                # Configuration Received Message Interface
                cfg_msg_received=Signal(bool(0)),
                cfg_msg_received_data=Signal(intbv(0)[8:]),
                cfg_msg_received_type=Signal(intbv(0)[5:]),

                # Configuration Transmit Message Interface
                cfg_msg_transmit=Signal(bool(0)),
                cfg_msg_transmit_type=Signal(intbv(0)[3:]),
                cfg_msg_transmit_data=Signal(intbv(0)[32:]),
                cfg_msg_transmit_done=Signal(bool(0)),

                # Configuration Flow Control Interface
                cfg_fc_ph=Signal(intbv(0)[8:]),
                cfg_fc_pd=Signal(intbv(0)[12:]),
                cfg_fc_nph=Signal(intbv(0)[8:]),
                cfg_fc_npd=Signal(intbv(0)[12:]),
                cfg_fc_cplh=Signal(intbv(0)[8:]),
                cfg_fc_cpld=Signal(intbv(0)[12:]),
                cfg_fc_sel=Signal(intbv(0)[3:]),

                # Per-Function Status Interface
                cfg_per_func_status_control=Signal(intbv(0)[3:]),
                cfg_per_func_status_data=Signal(intbv(0)[16:]),

                # Configuration Control Interface
                cfg_hot_reset_in=Signal(bool(0)),
                cfg_hot_reset_out=Signal(bool(0)),
                cfg_config_space_enable=Signal(bool(1)),
                cfg_per_function_update_done=Signal(bool(0)),
                cfg_per_function_number=Signal(intbv(0)[3:]),
                cfg_per_function_output_request=Signal(bool(0)),
                cfg_dsn=Signal(intbv(0)[64:]),
                cfg_ds_bus_number=Signal(intbv(0)[8:]),
                cfg_ds_device_number=Signal(intbv(0)[5:]),
                cfg_ds_function_number=Signal(intbv(0)[3:]),
                cfg_power_state_change_ack=Signal(bool(0)),
                cfg_power_state_change_interrupt=Signal(bool(0)),
                cfg_err_cor_in=Signal(bool(0)),
                cfg_err_uncor_in=Signal(bool(0)),
                cfg_flr_done=Signal(intbv(0)[2:]),
                cfg_vf_flr_done=Signal(intbv(0)[6:]),
                cfg_flr_in_process=Signal(intbv(0)[2:]),
                cfg_vf_flr_in_process=Signal(intbv(0)[6:]),
                cfg_req_pm_transition_l23_ready=Signal(bool(0)),
                cfg_link_training_enable=Signal(bool(1)),

                # Configuration Interrupt Controller Interface
                cfg_interrupt_int=Signal(intbv(0)[4:]),
                cfg_interrupt_sent=Signal(bool(0)),
                cfg_interrupt_pending=Signal(intbv(0)[2:]),
                cfg_interrupt_msi_enable=Signal(intbv(0)[4:]),
                cfg_interrupt_msi_vf_enable=Signal(intbv(0)[8:]),
                cfg_interrupt_msi_mmenable=Signal(intbv(0)[12:]),
                cfg_interrupt_msi_mask_update=Signal(bool(0)),
                cfg_interrupt_msi_data=Signal(intbv(0)[32:]),
                cfg_interrupt_msi_select=Signal(intbv(0)[4:]),
                cfg_interrupt_msi_int=Signal(intbv(0)[32:]),
                cfg_interrupt_msi_pending_status=Signal(intbv(0)[32:]),
                cfg_interrupt_msi_pending_status_data_enable=Signal(bool(0)),
                cfg_interrupt_msi_pending_status_function_num=Signal(intbv(0)[4:]),
                cfg_interrupt_msi_sent=Signal(bool(0)),
                cfg_interrupt_msi_fail=Signal(bool(0)),
                cfg_interrupt_msix_enable=Signal(intbv(0)[4:]),
                cfg_interrupt_msix_mask=Signal(intbv(0)[4:]),
                cfg_interrupt_msix_vf_enable=Signal(intbv(0)[8:]),
                cfg_interrupt_msix_vf_mask=Signal(intbv(0)[8:]),
                cfg_interrupt_msix_address=Signal(intbv(0)[64:]),
                cfg_interrupt_msix_data=Signal(intbv(0)[32:]),
                cfg_interrupt_msix_int=Signal(bool(0)),
                cfg_interrupt_msix_sent=Signal(bool(0)),
                cfg_interrupt_msix_fail=Signal(bool(0)),
                cfg_interrupt_msi_attr=Signal(intbv(0)[3:]),
                cfg_interrupt_msi_tph_present=Signal(bool(0)),
                cfg_interrupt_msi_tph_type=Signal(intbv(0)[2:]),
                cfg_interrupt_msi_tph_st_tag=Signal(intbv(0)[9:]),
                cfg_interrupt_msi_function_number=Signal(intbv(0)[4:]),

                # Configuration Extend Interface
                cfg_ext_read_received=Signal(bool(0)),
                cfg_ext_write_received=Signal(bool(0)),
                cfg_ext_register_number=Signal(intbv(0)[10:]),
                cfg_ext_function_number=Signal(intbv(0)[8:]),
                cfg_ext_write_data=Signal(intbv(0)[32:]),
                cfg_ext_write_byte_enable=Signal(intbv(0)[4:]),
                cfg_ext_read_data=Signal(intbv(0)[32:]),
                cfg_ext_read_data_valid=Signal(bool(0)),

                # Clock and Reset Interface
                user_clk=Signal(bool(0)),
                user_reset=Signal(bool(0)),
                user_lnk_up=Signal(bool(0)),
                sys_clk=None,
                sys_clk_gt=None,
                sys_reset=None,
                pcie_perstn0_out=Signal(bool(0)),
                pcie_perstn1_in=Signal(bool(0)),
                pcie_perstn1_out=Signal(bool(0)),

                # debugging connections
                cq_pause=Signal(bool(0)),
                cc_pause=Signal(bool(0)),
                rq_pause=Signal(bool(0)),
                rc_pause=Signal(bool(0)),
            ):

        # validate parameters and widths
        self.dw = len(m_axis_cq_tdata)

        assert self.dw in [64, 128, 256]

        if self.user_clk_frequency < 1e6:
            self.user_clk_frequency *= 1e6

        assert self.pcie_generation in [1, 2, 3]
        assert self.pcie_link_width in [1, 2, 4, 8]
        assert self.user_clk_frequency in [62.5e6, 125e6, 250e6]
        assert self.alignment in ["address", "dword"]

        self.upstream_port.max_speed = self.pcie_generation
        self.upstream_port.max_width = self.pcie_link_width

        if self.dw != 256 or self.alignment != "dword":
            # straddle only supported with 256-bit, DWORD-aligned interface
            assert not self.straddle

        # TODO change this when support added
        assert self.alignment == 'dword'
        assert not self.straddle

        if self.pcie_generation == 1:
            if self.pcie_link_width in [1, 2]:
                assert self.dw == 64
                assert self.user_clk_frequency in [62.5e6, 125e6, 250e6]
            elif self.pcie_link_width == 4:
                assert self.dw == 64
                assert self.user_clk_frequency in [125e6, 250e6]
            elif self.pcie_link_width == 8:
                assert self.dw in [64, 128]
                if self.dw == 64:
                    assert self.user_clk_frequency == 250e6
                elif self.dw == 128:
                    assert self.user_clk_frequency == 125e6
        elif self.pcie_generation == 2:
            if self.pcie_link_width == 1:
                assert self.dw == 64
                assert self.user_clk_frequency in [62.5e6, 125e6, 250e6]
            elif self.pcie_link_width == 2:
                assert self.dw == 64
                assert self.user_clk_frequency in [125e6, 250e6]
            elif self.pcie_link_width == 4:
                assert self.dw in [64, 128]
                if self.dw == 64:
                    assert self.user_clk_frequency == 250e6
                elif self.dw == 128:
                    assert self.user_clk_frequency == 125e6
            elif self.pcie_link_width == 8:
                assert self.dw in [128, 256]
                if self.dw == 128:
                    assert self.user_clk_frequency == 250e6
                elif self.dw == 256:
                    assert self.user_clk_frequency == 125e6
        elif self.pcie_generation == 3:
            if self.pcie_link_width == 1:
                assert self.dw == 64
                assert self.user_clk_frequency in [125e6, 250e6]
            elif self.pcie_link_width == 2:
                assert self.dw in [64, 128]
                if self.dw == 64:
                    assert self.user_clk_frequency == 250e6
                elif self.dw == 128:
                    assert self.user_clk_frequency == 125e6
            elif self.pcie_link_width == 4:
                assert self.dw in [128, 256]
                if self.dw == 128:
                    assert self.user_clk_frequency == 250e6
                elif self.dw == 256:
                    assert self.user_clk_frequency == 125e6
            elif self.pcie_link_width == 8:
                assert self.dw == 256
                assert self.user_clk_frequency == 250e6

        # Completer reQuest Interface
        assert len(m_axis_cq_tdata) == self.dw
        assert len(m_axis_cq_tuser) == 85
        assert len(m_axis_cq_tlast) == 1
        assert len(m_axis_cq_tkeep) == self.dw/32
        assert len(m_axis_cq_tvalid) == 1
        assert len(m_axis_cq_tready) == 1
        assert len(pcie_cq_np_req) == 1
        assert len(pcie_cq_np_req_count) == 6

        # Completer Completion Interface
        assert len(s_axis_cc_tdata) == self.dw
        assert len(s_axis_cc_tuser) == 33
        assert len(s_axis_cc_tlast) == 1
        assert len(s_axis_cc_tkeep) == self.dw/32
        assert len(s_axis_cc_tvalid) == 1
        assert len(s_axis_cc_tready) == 1

        # Requester reQuest Interface
        assert len(s_axis_rq_tdata) == self.dw
        assert len(s_axis_rq_tuser) == 60
        assert len(s_axis_rq_tlast) == 1
        assert len(s_axis_rq_tkeep) == self.dw/32
        assert len(s_axis_rq_tvalid) == 1
        assert len(s_axis_rq_tready) == 1
        assert len(pcie_rq_seq_num) == 4
        assert len(pcie_rq_seq_num_vld) == 1
        assert len(pcie_rq_tag) >= 6
        assert len(pcie_rq_tag_av) == 2
        assert len(pcie_rq_tag_vld) == 1

        # Requester Completion Interface
        assert len(m_axis_rc_tdata) == self.dw
        assert len(m_axis_rc_tuser) == 75
        assert len(m_axis_rc_tlast) == 1
        assert len(m_axis_rc_tkeep) == self.dw/32
        assert len(m_axis_rc_tvalid) == 1
        assert len(m_axis_rc_tready) == 1

        # Transmit Flow Control Interface
        assert len(pcie_tfc_nph_av) == 2
        assert len(pcie_tfc_npd_av) == 2

        # Configuration Management Interface
        assert len(cfg_mgmt_addr) == 19
        assert len(cfg_mgmt_write) == 1
        assert len(cfg_mgmt_write_data) == 32
        assert len(cfg_mgmt_byte_enable) == 4
        assert len(cfg_mgmt_read) == 1
        assert len(cfg_mgmt_read_data) == 32
        assert len(cfg_mgmt_read_write_done) == 1
        assert len(cfg_mgmt_type1_cfg_reg_access) == 1

        # Configuration Status Interface
        assert len(cfg_phy_link_down) == 1
        assert len(cfg_phy_link_status) == 2
        assert len(cfg_negotiated_width) == 4
        assert len(cfg_current_speed) == 3
        assert len(cfg_max_payload) == 3
        assert len(cfg_max_read_req) == 3
        assert len(cfg_function_status) == 8
        assert len(cfg_vf_status) == 12
        assert len(cfg_function_power_state) == 6
        assert len(cfg_vf_power_state) == 18
        assert len(cfg_link_power_state) == 2
        assert len(cfg_err_cor_out) == 1
        assert len(cfg_err_nonfatal_out) == 1
        assert len(cfg_err_fatal_out) == 1
        assert len(cfg_ltr_enable) == 1
        assert len(cfg_ltssm_state) == 6
        assert len(cfg_rcb_status) == 2
        assert len(cfg_dpa_substate_change) == 2
        assert len(cfg_obff_enable) == 2
        assert len(cfg_pl_status_change) == 1
        assert len(cfg_tph_requester_enable) == 2
        assert len(cfg_tph_st_mode) == 6
        assert len(cfg_vf_tph_requester_enable) == 6
        assert len(cfg_vf_tph_st_mode) == 18

        # Configuration Received Message Interface
        assert len(cfg_msg_received) == 1
        assert len(cfg_msg_received_data) == 8
        assert len(cfg_msg_received_type) == 5

        # Configuration Transmit Message Interface
        assert len(cfg_msg_transmit) == 1
        assert len(cfg_msg_transmit_type) == 3
        assert len(cfg_msg_transmit_data) == 32
        assert len(cfg_msg_transmit_done) == 1

        # Configuration Flow Control Interface
        assert len(cfg_fc_ph) == 8
        assert len(cfg_fc_pd) == 12
        assert len(cfg_fc_nph) == 8
        assert len(cfg_fc_npd) == 12
        assert len(cfg_fc_cplh) == 8
        assert len(cfg_fc_cpld) == 12
        assert len(cfg_fc_sel) == 3

        # Per-Function Status Interface
        assert len(cfg_per_func_status_control) == 3
        assert len(cfg_per_func_status_data) == 16

        # Configuration Control Interface
        assert len(cfg_hot_reset_in) == 1
        assert len(cfg_hot_reset_out) == 1
        assert len(cfg_config_space_enable) == 1
        assert len(cfg_per_function_update_done) == 1
        assert len(cfg_per_function_number) == 3
        assert len(cfg_per_function_output_request) == 1
        assert len(cfg_dsn) == 64
        assert len(cfg_ds_bus_number) == 8
        assert len(cfg_ds_device_number) == 5
        assert len(cfg_ds_function_number) == 3
        assert len(cfg_power_state_change_ack) == 1
        assert len(cfg_power_state_change_interrupt) == 1
        assert len(cfg_err_cor_in) == 1
        assert len(cfg_err_uncor_in) == 1
        assert len(cfg_flr_done) == 2
        assert len(cfg_vf_flr_done) == 6
        assert len(cfg_flr_in_process) == 2
        assert len(cfg_vf_flr_in_process) == 6
        assert len(cfg_req_pm_transition_l23_ready) == 1
        assert len(cfg_link_training_enable) == 1

        # Configuration Interrupt Controller Interface
        assert len(cfg_interrupt_int) == 4
        assert len(cfg_interrupt_sent) == 1
        assert len(cfg_interrupt_pending) == 2
        assert len(cfg_interrupt_msi_enable) == 4
        assert len(cfg_interrupt_msi_vf_enable) == 8
        assert len(cfg_interrupt_msi_mmenable) == 12
        assert len(cfg_interrupt_msi_mask_update) == 1
        assert len(cfg_interrupt_msi_data) == 32
        assert len(cfg_interrupt_msi_select) == 4
        assert len(cfg_interrupt_msi_int) == 32
        assert len(cfg_interrupt_msi_pending_status) == 32
        assert len(cfg_interrupt_msi_pending_status_data_enable) == 1
        assert len(cfg_interrupt_msi_pending_status_function_num) == 4
        assert len(cfg_interrupt_msi_sent) == 1
        assert len(cfg_interrupt_msi_fail) == 1
        assert len(cfg_interrupt_msix_enable) == 4
        assert len(cfg_interrupt_msix_mask) == 4
        assert len(cfg_interrupt_msix_vf_enable) == 8
        assert len(cfg_interrupt_msix_vf_mask) == 8
        assert len(cfg_interrupt_msix_address) == 64
        assert len(cfg_interrupt_msix_data) == 32
        assert len(cfg_interrupt_msix_int) == 1
        assert len(cfg_interrupt_msix_sent) == 1
        assert len(cfg_interrupt_msix_fail) == 1
        assert len(cfg_interrupt_msi_attr) == 3
        assert len(cfg_interrupt_msi_tph_present) == 1
        assert len(cfg_interrupt_msi_tph_type) == 2
        assert len(cfg_interrupt_msi_tph_st_tag) == 9
        assert len(cfg_interrupt_msi_function_number) == 4

        # Configuration Extend Interface
        assert len(cfg_ext_read_received) == 1
        assert len(cfg_ext_write_received) == 1
        assert len(cfg_ext_register_number) == 10
        assert len(cfg_ext_function_number) == 8
        assert len(cfg_ext_write_data) == 32
        assert len(cfg_ext_write_byte_enable) == 4
        assert len(cfg_ext_read_data) == 32
        assert len(cfg_ext_read_data_valid) == 1

        # Clock and Reset Interface
        assert len(user_clk) == 1
        assert len(user_reset) == 1
        assert len(user_lnk_up) == 1
        assert len(sys_clk) == 1
        assert len(sys_clk_gt) == 1
        assert len(sys_reset) == 1
        assert len(pcie_perstn0_out) == 1
        assert len(pcie_perstn1_in) == 1
        assert len(pcie_perstn1_out) == 1

        assert not self.has_logic

        self.has_logic = True

        # sources and sinks
        cq_source_logic = self.cq_source.create_logic(
            user_clk,
            user_reset,
            tdata=m_axis_cq_tdata,
            tuser=m_axis_cq_tuser,
            tlast=m_axis_cq_tlast,
            tkeep=m_axis_cq_tkeep,
            tvalid=m_axis_cq_tvalid,
            tready=m_axis_cq_tready,
            name='cq_source',
            pause=cq_pause
        )

        cc_sink_logic = self.cc_sink.create_logic(
            user_clk,
            user_reset,
            tdata=s_axis_cc_tdata,
            tuser=s_axis_cc_tuser,
            tlast=s_axis_cc_tlast,
            tkeep=s_axis_cc_tkeep,
            tvalid=s_axis_cc_tvalid,
            tready=s_axis_cc_tready,
            name='cc_sink',
            pause=cc_pause
        )

        rq_sink_logic = self.rq_sink.create_logic(
            user_clk,
            user_reset,
            tdata=s_axis_rq_tdata,
            tuser=s_axis_rq_tuser,
            tlast=s_axis_rq_tlast,
            tkeep=s_axis_rq_tkeep,
            tvalid=s_axis_rq_tvalid,
            tready=s_axis_rq_tready,
            name='rq_sink',
            pause=rq_pause
        )

        rc_source_logic = self.rc_source.create_logic(
            user_clk,
            user_reset,
            tdata=m_axis_rc_tdata,
            tuser=m_axis_rc_tuser,
            tlast=m_axis_rc_tlast,
            tkeep=m_axis_rc_tkeep,
            tvalid=m_axis_rc_tvalid,
            tready=m_axis_rc_tready,
            name='rc_source',
            pause=rc_pause
        )

        if self.user_clk_frequency == 62.5e6:
            user_clk_period = 8
        elif self.user_clk_frequency == 125e6:
            user_clk_period = 4
        else:
            user_clk_period = 2

        @always(delay(user_clk_period))
        def clkgen():
            user_clk.next = not user_clk

        @instance
        def reset_logic():
            while True:
                yield user_clk.posedge, sys_reset.negedge

                if not sys_reset:
                    user_reset.next = 1
                    yield sys_reset.posedge
                    yield delay(20)
                    yield user_clk.posedge
                    user_reset.next = 0

        @always_comb
        def comb_logic():
            pcie_perstn0_out.next = sys_reset
            pcie_perstn1_out.next = pcie_perstn1_in

        @instance
        def logic():

            while True:
                yield user_clk.posedge, sys_reset.negedge

                if not sys_reset:
                    self.cq_np_req_count = 0
                elif pcie_cq_np_req:
                    if self.cq_np_req_count < 32:
                        self.cq_np_req_count += 1

                # handle completer requests
                # send any queued non-posted requests first
                while self.cq_np_queue and self.cq_np_req_count > 0:
                    tlp = self.cq_np_queue.pop(0)
                    self.cq_np_req_count -= 1
                    self.cq_source.send(tlp.pack_us_cq())

                # handle new requests
                while self.cq_queue:
                    tlp = self.cq_queue.pop(0)

                    if (tlp.fmt_type == TLP_IO_READ or tlp.fmt_type == TLP_IO_WRITE or
                            tlp.fmt_type == TLP_MEM_READ or tlp.fmt_type == TLP_MEM_READ_64):
                        # non-posted request
                        if self.cq_np_req_count > 0:
                            # have credit, can forward
                            self.cq_np_req_count -= 1
                            self.cq_source.send(tlp.pack_us_cq())
                        else:
                            # no credits, put it in the queue
                            self.cq_np_queue.append(tlp)
                    else:
                        # posted request
                        self.cq_source.send(tlp.pack_us_cq())

                pcie_cq_np_req_count.next = self.cq_np_req_count

                # handle completer completions
                while not self.cc_sink.empty():
                    pkt = self.cc_sink.recv()

                    tlp = TLP_us().unpack_us_cc(pkt, self.enable_parity)

                    if not tlp.completer_id_enable:
                        tlp.completer_id = PcieId(self.bus_num, self.device_num, tlp.completer_id.function)

                    if not tlp.discontinue:
                        yield from self.send(TLP(tlp))

                # handle requester requests
                while not self.rq_sink.empty():
                    pkt = self.rq_sink.recv()

                    tlp = TLP_us().unpack_us_rq(pkt, self.enable_parity)

                    if not tlp.requester_id_enable:
                        tlp.requester_id = PcieId(self.bus_num, self.device_num, tlp.requester_id.function)

                    if not tlp.discontinue:
                        if self.functions[tlp.requester_id.function].bus_master_enable:
                            self.rq_seq_num.append(tlp.seq_num)
                            yield from self.send(TLP(tlp))
                        else:
                            print("Bus mastering disabled")

                            # TODO: internal response

                # transmit sequence number
                pcie_rq_seq_num_vld.next = 0
                if self.rq_seq_num:
                    pcie_rq_seq_num.next = self.rq_seq_num.pop(0)
                    pcie_rq_seq_num_vld.next = 1

                # TODO pcie_rq_tag

                # handle requester completions
                while self.rc_queue:
                    tlp = self.rc_queue.pop(0)
                    self.rc_source.send(tlp.pack_us_rc())

                # transmit flow control
                # TODO
                pcie_tfc_nph_av.next = 0x3
                pcie_tfc_npd_av.next = 0x3

                # configuration management
                if cfg_mgmt_read_write_done:
                    cfg_mgmt_read_write_done.next = 0
                elif cfg_mgmt_read:
                    if cfg_mgmt_addr & (1 << 18):
                        # internal register access
                        pass
                    else:
                        # PCI configuration register access
                        function = (cfg_mgmt_addr >> 10) & 0x7f
                        reg_num = cfg_mgmt_addr & 0x3ff
                        cfg_mgmt_read_data.next = self.functions[function].read_config_register(reg_num)
                    cfg_mgmt_read_write_done.next = 1
                elif cfg_mgmt_write:
                    if cfg_mgmt_addr & (1 << 18):
                        # internal register access
                        pass
                    else:
                        # PCI configuration register access
                        function = (cfg_mgmt_addr >> 10) & 0x7f
                        reg_num = cfg_mgmt_addr & 0x3ff
                        self.functions[function].write_config_register(reg_num, cfg_mgmt_write_data, cfg_mgmt_byte_enable)
                    cfg_mgmt_read_write_done.next = 1
                #cfg_mgmt_type1_cfg_reg_access

                # configuration status
                if not sys_reset:
                    cfg_phy_link_down.next = 1
                    user_lnk_up.next = 0
                else:
                    cfg_phy_link_down.next = 0 # TODO
                    user_lnk_up.next = 1 # TODO

                #cfg_phy_link_status
                cfg_negotiated_width.next = self.functions[0].negotiated_link_width
                cfg_current_speed.next = (1 << (self.functions[0].current_link_speed & 3)) >> 1
                cfg_max_payload.next = self.functions[0].max_payload_size
                cfg_max_read_req.next = self.functions[0].max_read_request_size

                status = 0
                if self.functions[0].bus_master_enable:
                    status |= 0x07
                if self.functions[0].interrupt_disable:
                    status |= 0x08
                if len(self.functions) > 1:
                    if self.functions[1].bus_master_enable:
                        status |= 0x70
                    if self.functions[1].interrupt_disable:
                        status |= 0x80
                cfg_function_status.next = status

                #cfg_vf_status
                #cfg_function_power_state
                #cfg_vf_power_state
                #cfg_link_power_state
                #cfg_err_cor_out
                #cfg_err_nonfatal_out
                #cfg_err_fatal_out
                cfg_ltr_enable.next = self.functions[0].ltr_mechanism_enable
                #cfg_ltssm_state

                status = 0
                if self.functions[0].read_completion_boundary:
                    status |= 1
                if len(self.functions) > 1:
                    if self.functions[0].read_completion_boundary:
                        status |= 2
                cfg_rcb_status.next = status

                #cfg_dpa_substate_change
                #cfg_obff_enable
                #cfg_pl_status_change
                #cfg_tph_requester_enable
                #cfg_tph_st_mode
                #cfg_vf_tph_requester_enable
                #cfg_vf_tph_st_mode

                # configuration received message
                #cfg_msg_received
                #cfg_msg_received_data
                #cfg_msg_received_type

                # configuration transmit message
                #cfg_msg_transmit
                #cfg_msg_transmit_type
                #cfg_msg_transmit_data
                #cfg_msg_transmit_done

                # configuration flow control
                if (cfg_fc_sel == 0b000):
                    # Receive credits at link partner
                    # TODO
                    cfg_fc_ph.next = 0
                    cfg_fc_pd.next = 0
                    cfg_fc_nph.next = 0
                    cfg_fc_npd.next = 0
                    cfg_fc_cplh.next = 0
                    cfg_fc_cpld.next = 0
                elif (cfg_fc_sel == 0b001):
                    # Receive credit limit
                    # TODO
                    cfg_fc_ph.next = 0x80
                    cfg_fc_pd.next = 0x800
                    cfg_fc_nph.next = 0x80
                    cfg_fc_npd.next = 0x800
                    cfg_fc_cplh.next = 0x80
                    cfg_fc_cpld.next = 0x800
                elif (cfg_fc_sel == 0b010):
                    # Receive credits consumed
                    # TODO
                    cfg_fc_ph.next = 0
                    cfg_fc_pd.next = 0
                    cfg_fc_nph.next = 0
                    cfg_fc_npd.next = 0
                    cfg_fc_cplh.next = 0
                    cfg_fc_cpld.next = 0
                elif (cfg_fc_sel == 0b011):
                    # Available space in receive buffer
                    # TODO
                    cfg_fc_ph.next = 0
                    cfg_fc_pd.next = 0
                    cfg_fc_nph.next = 0
                    cfg_fc_npd.next = 0
                    cfg_fc_cplh.next = 0
                    cfg_fc_cpld.next = 0
                elif (cfg_fc_sel == 0b100):
                    # Transmit credits available
                    # TODO
                    cfg_fc_ph.next = 0x80
                    cfg_fc_pd.next = 0x800
                    cfg_fc_nph.next = 0x80
                    cfg_fc_npd.next = 0x800
                    cfg_fc_cplh.next = 0x80
                    cfg_fc_cpld.next = 0x800
                elif (cfg_fc_sel == 0b101):
                    # Transmit credit limit
                    # TODO
                    cfg_fc_ph.next = 0x80
                    cfg_fc_pd.next = 0x800
                    cfg_fc_nph.next = 0x80
                    cfg_fc_npd.next = 0x800
                    cfg_fc_cplh.next = 0x80
                    cfg_fc_cpld.next = 0x800
                elif (cfg_fc_sel == 0b110):
                    # Transmit credits consumed
                    # TODO
                    cfg_fc_ph.next = 0
                    cfg_fc_pd.next = 0
                    cfg_fc_nph.next = 0
                    cfg_fc_npd.next = 0
                    cfg_fc_cplh.next = 0
                    cfg_fc_cpld.next = 0
                else:
                    # Reserved
                    cfg_fc_ph.next = 0
                    cfg_fc_pd.next = 0
                    cfg_fc_nph.next = 0
                    cfg_fc_npd.next = 0
                    cfg_fc_cplh.next = 0
                    cfg_fc_cpld.next = 0

                # per-function status
                #cfg_per_func_status_control
                #cfg_per_func_status_data

                # configuration control
                #cfg_hot_reset_in
                #cfg_hot_reset_out

                if not sys_reset:
                    self.config_space_enable = False
                else:
                    self.config_space_enable = bool(cfg_config_space_enable)

                #cfg_per_function_update_done
                #cfg_per_function_number
                #cfg_per_function_output_request
                #cfg_dsn
                #cfg_ds_bus_number
                #cfg_ds_device_number
                #cfg_ds_function_number
                #cfg_power_state_change_ack
                #cfg_power_state_change_interrupt
                #cfg_err_cor_in
                #cfg_err_uncor_in
                #cfg_flr_done
                #cfg_vf_flr_done
                #cfg_flr_in_process
                #cfg_vf_flr_in_process
                #cfg_req_pm_transition_l23_ready
                #cfg_link_training_enable

                # configuration interrupt controller
                # INTx
                #cfg_interrupt_int
                #cfg_interrupt_sent
                #cfg_interrupt_pending

                # MSI
                val = 0
                if self.functions[0].msi_enable:
                    val |= 1
                if len(self.functions) > 1:
                    if self.functions[1].msi_enable:
                        val |= 2
                cfg_interrupt_msi_enable.next = val

                #cfg_interrupt_msi_vf_enable

                cfg_interrupt_msi_sent.next = 0
                cfg_interrupt_msi_fail.next = 0
                if (cfg_interrupt_msi_int):
                    n = int(cfg_interrupt_msi_int)
                    #bits = [i for i in range(n.bit_length()) if n >> i & 1]
                    bits = [i for i in range(32) if n >> i & 1]
                    if len(bits) == 1 and cfg_interrupt_msi_function_number < len(self.functions):
                        yield self.functions[cfg_interrupt_msi_function_number].issue_msi_interrupt(bits[0], attr=int(cfg_interrupt_msi_attr))
                        cfg_interrupt_msi_sent.next = 1

                val = 0
                val |= self.functions[0].msi_multiple_message_enable & 0x7
                if len(self.functions) > 1:
                    val |= (self.functions[1].msi_multiple_message_enable & 0x7) << 3
                cfg_interrupt_msi_mmenable.next = val

                #cfg_interrupt_msi_mask_update

                if cfg_interrupt_msi_select == 0b1111:
                    cfg_interrupt_msi_data.next = 0
                else:
                    if cfg_interrupt_msi_select < len(self.functions):
                        cfg_interrupt_msi_data.next = self.functions[cfg_interrupt_msi_select].msi_mask_bits;
                    else:
                        cfg_interrupt_msi_data.next = 0
                if cfg_interrupt_msi_pending_status_data_enable:
                    if cfg_interrupt_msi_pending_status_function_num < len(self.functions):
                        self.functions[cfg_interrupt_msi_pending_status_function_num].msi_pending_bits = int(cfg_interrupt_msi_pending_status)

                # MSI-X
                val = 0
                if self.functions[0].msix_enable:
                    val |= 1
                if len(self.functions) > 1:
                    if self.functions[1].msix_enable:
                        val |= 2
                cfg_interrupt_msix_enable.next = val
                val = 0
                if self.functions[0].msix_function_mask:
                    val |= 1
                if len(self.functions) > 1:
                    if self.functions[1].msix_function_mask:
                        val |= 2
                cfg_interrupt_msix_mask.next = val
                #cfg_interrupt_msix_vf_enable
                #cfg_interrupt_msix_vf_mask

                cfg_interrupt_msix_sent.next = 0
                cfg_interrupt_msix_fail.next = 0
                if cfg_interrupt_msix_int:
                    if cfg_interrupt_msi_function_number < len(self.functions):
                        yield self.functions[cfg_interrupt_msi_function_number].issue_msix_interrupt(int(cfg_interrupt_msix_address), int(cfg_interrupt_msix_data), attr=int(cfg_interrupt_msi_attr))
                        cfg_interrupt_msix_sent.next = 1

                # MSI/MSI-X
                #cfg_interrupt_msi_tph_present
                #cfg_interrupt_msi_tph_type
                #cfg_interrupt_msi_tph_st_tag

                # configuration extend
                #cfg_ext_read_received
                #cfg_ext_write_received
                #cfg_ext_register_number
                #cfg_ext_function_number
                #cfg_ext_write_data
                #cfg_ext_write_byte_enable
                #cfg_ext_read_data
                #cfg_ext_read_data_valid

        return instances()

