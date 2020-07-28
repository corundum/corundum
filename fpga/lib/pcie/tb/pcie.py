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

import inspect
import math
import mmap
import struct
from myhdl import *

# TLP formats
FMT_3DW        = 0x0
FMT_4DW        = 0x1
FMT_3DW_DATA   = 0x2
FMT_4DW_DATA   = 0x3
FMT_TLP_PREFIX = 0x4

TLP_MEM_READ           = (FMT_3DW, 0x00)
TLP_MEM_READ_64        = (FMT_4DW, 0x00)
TLP_MEM_READ_LOCKED    = (FMT_3DW, 0x01)
TLP_MEM_READ_LOCKED_64 = (FMT_4DW, 0x01)
TLP_MEM_WRITE          = (FMT_3DW_DATA, 0x00)
TLP_MEM_WRITE_64       = (FMT_4DW_DATA, 0x00)
TLP_IO_READ            = (FMT_3DW, 0x02)
TLP_IO_WRITE           = (FMT_3DW_DATA, 0x02)
TLP_CFG_READ_0         = (FMT_3DW, 0x04)
TLP_CFG_WRITE_0        = (FMT_3DW_DATA, 0x04)
TLP_CFG_READ_1         = (FMT_3DW, 0x05)
TLP_CFG_WRITE_1        = (FMT_3DW_DATA, 0x05)
TLP_MSG_TO_RC          = (FMT_4DW, 0x10)
TLP_MSG_ADDR           = (FMT_4DW, 0x11)
TLP_MSG_ID             = (FMT_4DW, 0x12)
TLP_MSG_BCAST          = (FMT_4DW, 0x13)
TLP_MSG_LOCAL          = (FMT_4DW, 0x14)
TLP_MSG_GATHER         = (FMT_4DW, 0x15)
TLP_MSG_DATA_TO_RC     = (FMT_4DW_DATA, 0x10)
TLP_MSG_DATA_ADDR      = (FMT_4DW_DATA, 0x11)
TLP_MSG_DATA_ID        = (FMT_4DW_DATA, 0x12)
TLP_MSG_DATA_BCAST     = (FMT_4DW_DATA, 0x13)
TLP_MSG_DATA_LOCAL     = (FMT_4DW_DATA, 0x14)
TLP_MSG_DATA_GATHER    = (FMT_4DW_DATA, 0x15)
TLP_CPL                = (FMT_3DW, 0x0A)
TLP_CPL_DATA           = (FMT_3DW_DATA, 0x0A)
TLP_CPL_LOCKED         = (FMT_3DW, 0x0B)
TLP_CPL_LOCKED_DATA    = (FMT_3DW_DATA, 0x0B)
TLP_FETCH_ADD          = (FMT_3DW_DATA, 0x0C)
TLP_FETCH_ADD_64       = (FMT_4DW_DATA, 0x0C)
TLP_SWAP               = (FMT_3DW_DATA, 0x0D)
TLP_SWAP_64            = (FMT_4DW_DATA, 0x0D)
TLP_CAS                = (FMT_3DW_DATA, 0x0E)
TLP_CAS_64             = (FMT_4DW_DATA, 0x0E)
TLP_PREFIX_MRIOV       = (FMT_TLP_PREFIX, 0x00)
TLP_PREFIX_VENDOR_L0   = (FMT_TLP_PREFIX, 0x0E)
TLP_PREFIX_VENDOR_L1   = (FMT_TLP_PREFIX, 0x0F)
TLP_PREFIX_EXT_TPH     = (FMT_TLP_PREFIX, 0x10)
TLP_PREFIX_VENDOR_E0   = (FMT_TLP_PREFIX, 0x1E)
TLP_PREFIX_VENDOR_E1   = (FMT_TLP_PREFIX, 0x1F)

# Message types
MSG_UNLOCK         = 0x00
MSG_INVALIDATE_REQ = 0x01
MSG_INVALIDATE_CPL = 0x02
MSG_PAGE_REQ       = 0x04
MSG_PRG_RESP       = 0x05
MSG_LTR            = 0x10
MSG_OBFF           = 0x12
MSG_PM_AS_NAK      = 0x14
MSG_PM_PME         = 0x18
MSG_PME_TO         = 0x19
MSG_PME_TO_ACK     = 0x1A
MSG_ASSERT_INTA    = 0x20
MSG_ASSERT_INTB    = 0x21
MSG_ASSERT_INTC    = 0x22
MSG_ASSERT_INTD    = 0x23
MSG_DEASSERT_INTA  = 0x24
MSG_DEASSERT_INTB  = 0x25
MSG_DEASSERT_INTC  = 0x26
MSG_DEASSERT_INTD  = 0x27
MSG_ERR_COR        = 0x30
MSG_ERR_NONFATAL   = 0x31
MSG_ERR_FATAL      = 0x32
MSG_SET_SPL        = 0x50
MSG_VENDOR_0       = 0x7e
MSG_VENDOR_1       = 0x7f

AT_DEFAULT       = 0x0
AT_TRANSLATE_REQ = 0x1
AT_TRANSLATED    = 0x2

CPL_STATUS_SC  = 0x0 # successful completion
CPL_STATUS_UR  = 0x1 # unsupported request
CPL_STATUS_CRS = 0x2 # configuration request retry status
CPL_STATUS_CA  = 0x4 # completer abort

# PCIe capabilities
MSI_CAP_ID = 0x05
MSI_CAP_LEN = 6
MSIX_CAP_ID = 0x11
MSIX_CAP_LEN = 3

PM_CAP_ID = 0x01
PM_CAP_LEN = 2

PCIE_CAP_ID = 0x10
PCIE_CAP_LEN = 15

SEC_PCIE_EXT_CAP_ID = 0x0019
SEC_PCIE_EXT_CAP_LEN = 3

PCIE_GEN_RATE = {
    1: 2.5*8/10,
    2: 5*8/10,
    3: 8*128/130,
    4: 16*128/130,
    5: 32*128/130,
}


# debugging
trace_routing = False


def align(val, mask):
    if val & mask:
        return val + mask + 1 - (val & mask)
    else:
        return val


def byte_mask_update(old, mask, new, bitmask=-1):
    new = (new & bitmask) | (old & ~bitmask)
    m1 = 1
    m2 = 0xff
    while mask >= m1:
        if mask & m1:
            old = (old & ~m2) | (new & m2)
        m1 <<= 1
        m2 <<= 8
    return old


def highlight(s):
    return "\033[32m%s\033[0m" % s


class PcieId(object):
    def __init__(self, bus=0, device=0, function=0):
        self.bus = 0
        self.device = 0
        self.function = 0
        if isinstance(bus, PcieId):
            self.bus = bus.bus
            self.device = bus.device
            self.function = bus.function
        elif isinstance(bus, tuple):
            self.bus, self.device, self.function = bus
        else:
            self.bus = bus
            self.device = device
            self.function = function

    @classmethod
    def from_int(cls, val):
        return cls((val >> 8) & 0xff, (val >> 3) & 0x1f, val & 0x7)

    def __eq__(self, other):
        if isinstance(other, PcieId):
            return self.bus == other.bus and self.device == other.device and self.function == other.function
        return False

    def __int__(self):
        return ((self.bus & 0xff) << 8) | ((self.device & 0x1f) << 3) | (self.function & 0x7)

    def __str__(self):
        return "%02x:%02x.%x" % (self.bus, self.device, self.function)

    def __repr__(self):
        return "PcieId(%d, %d, %d)" % (self.bus, self.device, self.function)


class PcieCap(object):
    def __init__(self, cap_id, cap_ver=None, length=None, read=None, write=None, offset=None, next_cap=None):
        self.cap_id = cap_id
        self.cap_ver = cap_ver
        self.length = length
        self.read = read
        self.write = write
        self.offset = offset
        self.next_cap = next_cap

    def read_register(self, reg):
        val = self.read(reg)
        if reg == 0:
            val = (val & 0xffff0000) | ((self.next_cap & 0xff) << 8) | (self.cap_id & 0xff)
        return val

    def write_register(self, reg, data, mask):
        self.write(reg, data, mask)

    def __repr__(self):
        return "PcieCap(cap_id={:#x}, cap_ver={}, length={}, read={}, write={}, offset={}, next_cap={})".format(self.cap_id, repr(self.cap_ver), repr(self.length), repr(self.read), repr(self.write), repr(self.offset), repr(self.next_cap))


class PcieExtCap(PcieCap):
    def read_register(self, reg):
        if reg == 0:
            return ((self.next_cap & 0xfff) << 20) | ((self.cap_ver & 0xf) << 16) | (self.cap_id & 0xffff)
        return self.read(reg)


class PcieCapList(object):
    def __init__(self):
        self.cap_type = PcieCap
        self.list = []
        self.start = 0x10
        self.end = 0x3f

    def find_by_id(self, cap_id):
        for cap in self.list:
            if cap.cap_id == cap_id:
                return cap
        return None

    def find_by_reg(self, reg):
        for cap in self.list:
            if cap.offset <= reg < cap.offset+cap.length:
                return cap
        return None

    def read_register(self, reg):
        cap = self.find_by_reg(reg)
        if cap:
            return cap.read_register(reg-cap.offset)
        return 0

    def write_register(self, reg, data, mask):
        cap = self.find_by_reg(reg)
        if cap:
            cap.write_register(reg-cap.offset, data, mask)

    def register(self, cap_id, cap_ver=None, length=None, read=None, write=None, offset=None):
        if isinstance(cap_id, self.cap_type):
            new_cap = cap_id
        else:
            new_cap = self.find_by_id(cap_id)

            if new_cap:
                # re-registering cap

                # remove from list
                self.list.remove(new_cap)

                # update parameters
                if cap_ver is not None:
                    new_cap.cap_ver = cap_ver
                if length:
                    new_cap.length = length
                if read:
                    new_cap.read = read
                if write:
                    new_cap.write = write
                if offset:
                    new_cap.offset = offset

        if not new_cap:
            new_cap = self.cap_type(cap_id, cap_ver, length, read, write, offset)

        if not new_cap.length or not new_cap.read or not new_cap.write:
            raise Exception("Missing required parameter")

        bump_list = []

        if new_cap.offset:
            for cap in self.list:
                if cap.offset <= new_cap.offset+new_cap.length-1 and new_cap.offset <= cap.offset+cap.length-1:
                    bump_list.append(cap)
            for cap in bump_list:
                self.list.remove(cap)
        else:
            new_cap.offset = self.start
            for cap in self.list:
                if cap.offset < new_cap.offset+new_cap.length-1 and new_cap.offset <= cap.offset+cap.length-1:
                    new_cap.offset = cap.offset+cap.length

        self.list.append(new_cap)

        # sort list by offset
        self.list.sort(key=lambda x: x.offset)

        # update list next cap pointers
        for k in range(1, len(self.list)):
            self.list[k-1].next_cap = self.list[k].offset*4
            self.list[k].next_cap = 0

        # re-insert bumped caps
        for cap in bump_list:
            cap.offset = None
            self.register(cap)


class PcieExtCapList(PcieCapList):
    def __init__(self):
        super(PcieExtCapList, self).__init__()
        self.cap_type = PcieExtCap
        self.start = 0x40
        self.end = 0x3ff


class TLP(object):
    def __init__(self, tlp=None):
        self.fmt = 0
        self.type = 0
        self.tc = 0
        self.th = 0
        self.td = 0
        self.ep = 0
        self.attr = 0
        self.at = 0
        self.length = 0
        self.completer_id = PcieId(0, 0, 0)
        self.status = 0
        self.bcm = 0
        self.byte_count = 0
        self.requester_id = PcieId(0, 0, 0)
        self.dest_id = PcieId(0, 0, 0)
        self.tag = 0
        self.first_be = 0
        self.last_be = 0
        self.lower_address = 0
        self.address = 0
        self.register_number = 0
        self.data = []

        if isinstance(tlp, TLP):
            self.fmt = tlp.fmt
            self.type = tlp.type
            self.tc = tlp.tc
            self.td = tlp.td
            self.ep = tlp.ep
            self.attr = tlp.attr
            self.at = tlp.at
            self.length = tlp.length
            self.completer_id = tlp.completer_id
            self.status = tlp.status
            self.bcm = tlp.bcm
            self.byte_count = tlp.byte_count
            self.requester_id = tlp.requester_id
            self.dest_id = tlp.dest_id
            self.tag = tlp.tag
            self.first_be = tlp.first_be
            self.last_be = tlp.last_be
            self.lower_address = tlp.lower_address
            self.address = tlp.address
            self.register_number = tlp.register_number
            self.data = tlp.data

    @property
    def fmt_type(self):
        return (self.fmt, self.type)

    @fmt_type.setter
    def fmt_type(self, val):
        self.fmt, self.type = val

    @property
    def completer_id(self):
        return self._completer_id
    
    @completer_id.setter
    def completer_id(self, val):
        self._completer_id = PcieId(val)

    @property
    def requester_id(self):
        return self._requester_id
    
    @requester_id.setter
    def requester_id(self, val):
        self._requester_id = PcieId(val)

    @property
    def dest_id(self):
        return self._dest_id
    
    @dest_id.setter
    def dest_id(self, val):
        self._dest_id = PcieId(val)

    def check(self):
        """Validate TLP"""
        ret = True
        if self.fmt == FMT_3DW_DATA or self.fmt == FMT_4DW_DATA:
            if self.length != len(self.data):
                print("TLP validation failed, length field does not match data: %s" % repr(self))
                ret = False
            if 0 > self.length > 1024:
                print("TLP validation failed, length out of range: %s" % repr(self))
                ret = False
        if (self.fmt_type == TLP_MEM_READ or self.fmt_type == TLP_MEM_READ_64 or
                self.fmt_type == TLP_MEM_READ_LOCKED or self.fmt_type == TLP_MEM_READ_LOCKED_64 or
                self.fmt_type == TLP_MEM_WRITE or self.fmt_type == TLP_MEM_WRITE_64):
            if self.length*4 > 0x1000 - (self.address & 0xfff):
                print("TLP validation failed, request crosses 4K boundary: %s" % repr(self))
                ret = False
        if (self.fmt_type == TLP_IO_READ or self.fmt_type == TLP_IO_WRITE):
            if self.length != 1:
                print("TLP validation failed, invalid length for IO request: %s" % repr(self))
                ret = False
            if self.last_be != 0:
                print("TLP validation failed, invalid last BE for IO request: %s" % repr(self))
                ret = False
        if (self.fmt_type == TLP_CPL_DATA):
            if (self.byte_count + (self.lower_address&3) + 3) < self.length*4:
                print("TLP validation failed, completion byte count too small: %s" % repr(self))
                ret = False
        return ret

    def set_completion(self, tlp, completer_id, has_data=False, status=CPL_STATUS_SC):
        """Prepare completion for TLP"""
        if has_data:
            self.fmt_type = TLP_CPL_DATA
        else:
            self.fmt_type = TLP_CPL
        self.requester_id = tlp.requester_id
        self.completer_id = completer_id
        self.status = status
        self.attr = tlp.attr
        self.tag = tlp.tag
        self.tc = tlp.tc

    def set_completion_data(self, tlp, completer_id):
        """Prepare completion with data for TLP"""
        self.set_completion(tlp, completer_id, True)

    def set_ur_completion(self, tlp, completer_id):
        """Prepare unsupported request (UR) completion for TLP"""
        self.set_completion(tlp, completer_id, False, CPL_STATUS_UR)

    def set_crs_completion(self, tlp, completer_id):
        """Prepare configuration request retry status (CRS) completion for TLP"""
        self.set_completion(tlp, completer_id, False, CPL_STATUS_CRS)

    def set_ca_completion(self, tlp, completer_id):
        """Prepare completer abort (CA) completion for TLP"""
        self.set_completion(tlp, completer_id, False, CPL_STATUS_CA)

    def set_be(self, addr, length):
        """Compute byte enables, DWORD address, and DWORD length from byte address and length"""
        self.address = addr & ~3
        first_pad = addr % 4
        last_pad = 3 - (addr+length-1) % 4
        self.length = math.ceil((length+first_pad+last_pad)/4)
        self.first_be = (0xf << first_pad) & 0xf
        self.last_be = (0xf >> last_pad)
        if self.length == 1:
            self.first_be &= self.last_be
            self.last_be = 0

        return (first_pad, last_pad)

    def set_data(self, data):
        """Set DWORD data from byte data"""
        self.data = []
        for k in range(0, len(data), 4):
            self.data.append(struct.unpack('<L', data[k:k+4])[0])
        self.length = len(self.data)

    def set_be_data(self, addr, data):
        """Set byte enables, DWORD address, DWORD length, and DWORD data from byte address and byte data"""
        self.address = addr & ~3
        first_pad, last_pad = self.set_be(addr, len(data))
        self.set_data(bytearray(first_pad)+data+bytearray(last_pad))

    def get_data(self):
        data = bytearray()
        for dw in self.data:
            data.extend(struct.pack('<L', dw))
        return data

    def get_first_be_offset(self):
        """Offset to first transferred byte from first byte enable"""
        if self.first_be & 0x7 == 0:
            return 3
        elif self.first_be & 0x3 == 0:
            return 2
        elif self.first_be & 0x1 == 0:
            return 1
        else:
            return 0

    def get_last_be_offset(self):
        """Offset after last transferred byte from last byte enable"""
        if self.length == 1:
            be = self.first_be
        else:
            be = self.last_be
        if be & 0xf == 0x1:
            return 3
        elif be & 0xe == 0x2:
            return 2
        elif be & 0xc == 0x4:
            return 1
        else:
            return 0

    def get_be_byte_count(self):
        """Compute byte length from DWORD length and byte enables"""
        return self.length*4 - self.get_first_be_offset() - self.get_last_be_offset()

    def get_lower_address(self):
        """Compute lower address field from address and first byte enable"""
        return self.address & 0x7c + self.get_first_be_offset()

    def get_size(self):
        """Return size of TLP in bytes"""
        if self.fmt == FMT_3DW:
            return 12
        elif self.fmt == FMT_3DW_DATA:
            return 12+len(self.data)*4
        elif self.fmt == FMT_4DW:
            return 16
        elif self.fmt == FMT_4DW_DATA:
            return 16+len(self.data)*4

    def get_wire_size(self):
        """Return size of TLP in bytes, including overhead"""
        return self.get_size()+12

    def get_data_credits(self):
        """Return size of TLP in data credits (1 credit per 4 DW)"""
        return int((len(self.data)+3)/4)

    def pack(self):
        """Pack TLP as DWORD array"""
        pkt = []

        l = self.length & 0x3ff
        l |= (self.at & 0x3) << 10
        l |= (self.attr & 0x3) << 12
        l |= (self.ep & 1) << 14
        l |= (self.td & 1) << 15
        l |= (self.th & 1) << 16
        l |= (self.attr & 0x4) << 16
        l |= (self.tc & 0x7) << 20
        l |= (self.type & 0x1f) << 24
        l |= (self.fmt & 0x7) << 29
        pkt.append(l)

        if (self.fmt_type == TLP_CFG_READ_0 or self.fmt_type == TLP_CFG_WRITE_0 or
                self.fmt_type == TLP_CFG_READ_1 or self.fmt_type == TLP_CFG_WRITE_1 or
                self.fmt_type == TLP_MEM_READ or self.fmt_type == TLP_MEM_READ_64 or
                self.fmt_type == TLP_MEM_READ_LOCKED or self.fmt_type == TLP_MEM_READ_LOCKED_64 or
                self.fmt_type == TLP_MEM_WRITE or self.fmt_type == TLP_MEM_WRITE_64 or
                self.fmt_type == TLP_IO_READ or self.fmt_type == TLP_IO_WRITE):
            l = self.first_be & 0xf
            l |= (self.last_be & 0xf) << 4
            l |= (self.tag & 0xff) << 8
            l |= int(self.requester_id) << 16
            pkt.append(l)

            if (self.fmt_type == TLP_CFG_READ_0 or self.fmt_type == TLP_CFG_WRITE_0 or
                    self.fmt_type == TLP_CFG_READ_1 or self.fmt_type == TLP_CFG_WRITE_1):
                l = (self.register_number & 0x3ff) << 2
                l |= int(self.dest_id) << 16
                pkt.append(l)
            else:
                l = 0
                if self.fmt == FMT_4DW or self.fmt == FMT_4DW_DATA:
                    l |= (self.address >> 32) & 0xffffffff
                    pkt.append(l)
                l |= self.address & 0xfffffffc
                pkt.append(l)
        elif (self.fmt_type == TLP_CPL or self.fmt_type == TLP_CPL_DATA or
                self.fmt_type == TLP_CPL_LOCKED or self.fmt_type == TLP_CPL_LOCKED_DATA):
            l = self.byte_count & 0xfff
            l |= (self.bcm & 1) << 12
            l |= (self.status & 0x7) << 13
            l |= int(self.completer_id) << 16
            pkt.append(l)
            l = self.lower_address & 0x7f
            l |= (self.tag & 0xff) << 8
            l |= int(self.requester_id) << 16
            pkt.append(l)
        else:
            raise Exception("Unknown TLP type")

        if self.fmt == FMT_3DW_DATA or self.fmt == FMT_4DW_DATA:
            pkt.extend(self.data)

        return pkt

    def unpack(self, pkt):
        """Unpack TLP from DWORD array"""
        self.length = pkt[0] & 0x3ff
        self.at = (pkt[0] >> 10) & 0x3
        self.attr = (pkt[0] >> 12) & 0x3
        self.ep = (pkt[0] >> 14) & 1
        self.td = (pkt[0] >> 15) & 1
        self.th = (pkt[0] >> 16) & 1
        self.attr |= (pkt[0] >> 16) & 0x4
        self.tc = (pkt[0] >> 20) & 0x7
        self.type = (pkt[0] >> 24) & 0x1f
        self.fmt = (pkt[0] >> 29) & 0x7

        if self.fmt == FMT_3DW_DATA or self.fmt == FMT_4DW_DATA:
            if self.length == 0:
                self.length = 1024

        if (self.fmt_type == TLP_CFG_READ_0 or self.fmt_type == TLP_CFG_WRITE_0 or
                self.fmt_type == TLP_CFG_READ_1 or self.fmt_type == TLP_CFG_WRITE_1 or
                self.fmt_type == TLP_MEM_READ or self.fmt_type == TLP_MEM_READ_64 or
                self.fmt_type == TLP_MEM_READ_LOCKED or self.fmt_type == TLP_MEM_READ_LOCKED_64 or
                self.fmt_type == TLP_MEM_WRITE or self.fmt_type == TLP_MEM_WRITE_64 or
                self.fmt_type == TLP_IO_READ or self.fmt_type == TLP_IO_WRITE):
            self.first_be = pkt[1] & 0xf
            self.last_be = (pkt[1] >> 4) & 0xf
            self.tag = (pkt[1] >> 8) & 0xff
            self.requester_id = PcieId.from_int(pkt[1] >> 16)

            if (self.fmt_type == TLP_CFG_READ_0 or self.fmt_type == TLP_CFG_WRITE_0 or
                    self.fmt_type == TLP_CFG_READ_1 or self.fmt_type == TLP_CFG_WRITE_1):
                self.register_number = (pkt[2] >> 2) >> 0x3ff
                self.dest_id = PcieId.from_int(pkt[2] >> 16)
            elif self.fmt == FMT_3DW or self.fmt == FMT_3DW_DATA:
                self.address = pkt[3] & 0xfffffffc
            elif self.fmt == FMT_4DW or self.fmt == FMT_4DW_DATA:
                self.address = (pkt[4] & 0xffffffff) << 32 | pkt[4] & 0xfffffffc
        elif (self.fmt_type == TLP_CPL or self.fmt_type == TLP_CPL_DATA or
                self.fmt_type == TLP_CPL_LOCKED or self.fmt_type == TLP_CPL_LOCKED_DATA):
            self.byte_count = pkt[1] & 0xfff
            self.bcm = (pkt[1] >> 12) & 1
            self.status = (pkt[1] >> 13) & 0x7
            self.completer_id = PcieId.from_int(pkt[1] >> 16)
            self.lower_address = pkt[2] & 0x7f
            self.tag = (pkt[2] >> 8) & 0xff
            self.requester_id = PcieId.from_int(pkt[2] >> 16)

            if self.byte_count == 0:
                self.byte_count = 4096
        else:
            raise Exception("Unknown TLP type")

        if self.fmt == FMT_3DW_DATA:
            self.data = pkt[3:]
        elif self.fmt == FMT_4DW_DATA:
            self.data = pkt[4:]

        return self

    def __eq__(self, other):
        if isinstance(other, TLP):
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
                ('TLP(data=[%s], ' % ', '.join(hex(x) for x in self.data)) +
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


class Port(object):
    """Basic port"""
    def __init__(self, parent=None, rx_handler=None):
        self.parent = parent
        self.other = None
        self.rx_handler = rx_handler

        self.tx_queue = []
        self.tx_scheduled = False

        self.max_speed = 3
        self.max_width = 16
        self.port_delay = 5

        self.cur_speed = 1
        self.cur_width = 1
        self.link_delay = 0

    def connect(self, port):
        if isinstance(port, Port):
            self._connect(port)
        else:
            port.connect(self)

    def _connect(self, port):
        if self.other is not None:
            raise Exception("Already connected")
        port._connect_int(self)
        self._connect_int(port)

    def _connect_int(self, port):
        if self.other is not None:
            raise Exception("Already connected")
        self.other = port
        self.cur_speed = min(self.max_speed, port.max_speed)
        self.cur_width = min(self.max_width, port.max_width)
        self.link_delay = self.port_delay + port.port_delay

    def send(self, tlp):
        self.tx_queue.append(tlp)
        if not self.tx_scheduled:
            # schedule transmit
            yield self.transmit(), None
            self.tx_scheduled = True

    def transmit(self):
        if self.tx_queue:
            # schedule transmit
            tlp = self.tx_queue.pop(0)
            d = tlp.get_wire_size()*8/(PCIE_GEN_RATE[self.cur_speed]*self.cur_width)
            yield delay(int(d))
            yield self.transmit(), None
            yield delay(int(self.link_delay))
            yield self._transmit(tlp)
        else:
            self.tx_scheduled = False

    def _transmit(self, tlp):
        if self.other is None:
            raise Exception("Port not connected")
        yield from self.other.ext_recv(tlp)

    def ext_recv(self, tlp):
        if self.rx_handler is None:
            raise Exception("Receive handler not set")
        yield from self.rx_handler(tlp)


class BusPort(Port):
    """Port for root of bus interconnection, broadcasts TLPs to all connected ports"""
    def __init__(self, parent=None, rx_handler=None):
        super(BusPort, self).__init__(parent, rx_handler)

        self.other = []

    def _connect(self, port):
        if port in self.other:
            raise Exception("Already connected")
        port._connect_int(self)
        self._connect_int(port)

    def _connect_int(self, port):
        if port in self.other:
            raise Exception("Already connected")
        self.other.append(port)
        self.cur_speed = min(self.max_speed, port.max_speed)
        self.cur_width = min(self.max_width, port.max_width)
        self.link_delay = self.port_delay + port.port_delay

    def _transmit(self, tlp):
        if not self.other:
            raise Exception("Port not connected")
        for p in self.other:
            yield from p.ext_recv(TLP(tlp))


class PMCapability(object):
    """Power Management capability"""
    def __init__(self, *args, **kwargs):
        super(PMCapability, self).__init__(*args, **kwargs)

        # Power management capability registers
        self.pm_capabilities = 0
        self.pm_control_status = 0
        self.pm_data = 0

        self.register_capability(PM_CAP_ID, PM_CAP_LEN, self.read_pm_cap_register, self.write_pm_cap_register)

    """
    PCI Power Management Capability

    31                                                                  0
    +---------------------------------+----------------+----------------+
    |         PM Capabilities         |    Next Cap    |     PM Cap     |   0   0x00
    +----------------+----------------+----------------+----------------+
    |    PM Data     |                |        PM Control/Status        |   1   0x04
    +----------------+----------------+---------------------------------+
    """
    def read_pm_cap_register(self, reg):
        if   reg == 0: return self.pm_capabilities << 16
        elif reg == 1: return (self.pm_data << 24) | self.pm_control_status

    def write_pm_cap_register(self, reg, data, mask):
        # TODO
        pass


class PCIECapability(object):
    """PCI Express capability"""
    def __init__(self, *args, **kwargs):
        super(PCIECapability, self).__init__(*args, **kwargs)

        # PCIe capability registers
        # PCIe capabilities
        self.pcie_capability_version = 2
        self.pcie_device_type = 0
        self.pcie_slot_implemented = False
        self.interrupt_message_number = 0
        # Device capabilities
        self.max_payload_size_supported = 0x5
        self.phantom_functions_supported = 0
        self.extended_tag_supported = True
        self.endpoint_l0s_acceptable_latency = 0x7
        self.endpoint_l1_acceptable_latency = 0x7
        self.role_based_error_reporting = True # TODO check ECN
        self.captured_slot_power_limit_value = 0
        self.captured_slot_power_limit_scale = 0
        self.function_level_reset_capability = False
        # Device control
        self.correctable_error_reporting_enable = False
        self.non_fatal_error_reporting_enable = False
        self.fatal_error_reporting_enable = False
        self.unsupported_request_reporting_enable = False
        self.enable_relaxed_ordering = True
        self.max_payload_size = 0x0
        self.extended_tag_field_enable = False
        self.phantom_functions_enable = False
        self.aux_power_pm_enable = False
        self.enable_no_snoop = True
        self.max_read_request_size = 0x2
        # Device status
        self.correctable_error_detected = False
        self.nonfatal_error_detected = False
        self.fatal_error_detected = False
        self.unsupported_request_detected = False
        self.aux_power_detected = False
        self.transactions_pending = False
        # Link capabilities
        self.max_link_speed = 0
        self.max_link_width = 0
        self.aspm_support = 0
        self.l0s_exit_latency = 0
        self.l1_exit_latency = 0
        self.clock_power_management = False
        self.surprise_down_error_reporting_capability = False
        self.data_link_layer_link_active_reporting_capable = False
        self.link_bandwidth_notification_capability = False
        self.aspm_optionality_compliance = False
        self.port_number = 0
        # Link control
        self.aspm_control = 0
        self.read_completion_boundary = False
        self.link_disable = False
        self.common_clock_configuration = False
        self.extended_synch = False
        self.enable_clock_power_management = False
        self.hardware_autonomous_width_disable = False
        self.link_bandwidth_management_interrupt_enable = False
        self.link_autonomous_bandwidth_interrupt_enable = False
        # Link status
        self.current_link_speed = 0
        self.negotiated_link_width = 0
        self.link_training = False
        self.slot_clock_configuration = False
        self.data_link_layer_link_active = False
        self.link_bandwidth_management_status = False
        self.link_autonomous_bandwidth_status = False
        # Slot capabilities
        self.attention_button_present = False
        self.power_controller_present = False
        self.mrl_sensor_present = False
        self.attention_indicator_present = False
        self.power_indicator_present = False
        self.hot_plug_surprise = False
        self.hot_plug_capable = False
        self.slot_power_limit_value = 0
        self.slot_power_limit_scale = 0
        self.electromechanical_interlock_present = False
        self.no_command_completed_support = False
        self.physical_slot_number = 0
        # Slot control
        self.attention_button_pressed_enable = False
        self.power_fault_detected_enable = False
        self.mrl_sensor_changed_enable = False
        self.presence_detect_changed_enable = False
        self.command_completed_interrupt_enable = False
        self.hot_plug_interrupt_enable = False
        self.attention_indicator_control = 0
        self.power_indicator_control = 0
        self.power_controller_control = False
        self.electromechanical_interlock_control = False
        self.data_link_layer_state_changed_enable = False
        # Slot status
        self.attention_button_pressed = False
        self.power_fault_detected = False
        self.mrl_sensor_changed = False
        self.presence_detect_changed = False
        self.command_completed = False
        self.mrl_sensor_state = False
        self.presence_detect_state = False
        self.electromechanical_interlock_status = False
        self.data_link_layer_state_changed = False
        # Root control
        self.system_error_on_correctable_error_enable = False
        self.system_error_on_non_fatal_error_enable = False
        self.system_error_on_fatal_error_enable = False
        self.pme_interrupt_enable = False
        self.crs_software_visibility_enable = False
        # Root capabilities
        self.crs_software_visibility = False
        # Root status
        self.pme_requester_id = 0
        self.pme_status = False
        self.pme_pending = False
        # Device capabilities 2
        self.completion_timeout_ranges_supported = 0
        self.completion_timeout_disable_supported = False
        self.ari_forwarding_supported = False
        self.atomic_op_forwarding_supported = False
        self.atomic_op_32_bit_completer_supported = False
        self.atomic_op_64_bit_completer_supported = False
        self.cas_128_bit_completer_supported = False
        self.no_ro_enabled_pr_pr_passing = False
        self.ltr_mechanism_supported = False
        self.tph_completer_supported = 0
        self.obff_supported = 0
        self.extended_fmt_field_supported = False
        self.end_end_tlp_prefix_supported = False
        self.max_end_end_tlp_prefix = 0
        # Device control 2
        self.completion_timeout_value = 0
        self.completion_timeout_disable = False
        self.ari_forwarding_enable = False
        self.atomic_op_requester_enable = False
        self.atomic_op_egress_blocking = False
        self.ido_request_enable = False
        self.ido_completion_enable = False
        self.ltr_mechanism_enable = False
        self.obff_enable = 0
        self.end_end_tlp_prefix_blocking = False
        # Device status 2
        # Link capabilities 2
        self.supported_link_speeds = 0
        self.crosslink_supported = False
        # Link control 2
        self.target_link_speed = 0
        self.enter_compliance = False
        self.hardware_autonomous_speed_disable = False
        self.selectable_de_emphasis = False
        self.transmit_margin = 0
        self.enter_modified_compliance = False
        self.compliance_sos = False
        self.compliance_preset_de_emphasis = 0
        # Link status 2
        self.current_de_emphasis_level = False
        self.equalization_complete = False
        self.equalization_phase_1_successful = False
        self.equalization_phase_2_successful = False
        self.equalization_phase_3_successful = False
        self.link_equalization_request = False
        # Slot capabilities 2
        # Slot control 2
        # Slot status 2

        self.register_capability(PCIE_CAP_ID, PCIE_CAP_LEN, self.read_pcie_cap_register, self.write_pcie_cap_register)

    """
    PCIe Capability

    31                                                                  0
    +---------------------------------+----------------+----------------+
    |        PCIe Capabilities        |    Next Cap    |    PCIe Cap    |   0   0x00
    +---------------------------------+----------------+----------------+
    |                        Device Capabilities                        |   1   0x04
    +---------------------------------+---------------------------------+
    |          Device Status          |         Device Control          |   2   0x08
    +---------------------------------+----------------+----------------+
    |                         Link Capabilities                         |   3   0x0C
    +---------------------------------+---------------------------------+
    |           Link Status           |          Link Control           |   4   0x10
    +---------------------------------+---------------------------------+
    |                         Slot Capabilities                         |   5   0x14
    +---------------------------------+---------------------------------+
    |           Slot Status           |          Slot Control           |   6   0x18
    +---------------------------------+---------------------------------+
    |        Root Capabilities        |          Root Control           |   7   0x1C
    +---------------------------------+---------------------------------+
    |                            Root status                            |   8   0x20
    +---------------------------------+---------------------------------+
    |                       Device Capabilities 2                       |   9   0x24
    +---------------------------------+---------------------------------+
    |         Device Status 2         |        Device Control 2         |  10   0x28
    +---------------------------------+----------------+----------------+
    |                        Link Capabilities 2                        |  11   0x2C
    +---------------------------------+---------------------------------+
    |          Link Status 2          |         Link Control 2          |  12   0x30
    +---------------------------------+---------------------------------+
    |                        Slot Capabilities 2                        |  13   0x34
    +---------------------------------+---------------------------------+
    |          Slot Status 2          |         Slot Control 2          |  14   0x38
    +---------------------------------+---------------------------------+
    """
    def read_pcie_cap_register(self, reg):
        if reg == 0:
            # PCIe capabilities
            val = 2 << 16
            val |= (self.pcie_device_type & 0xf) << 20
            if self.pcie_slot_implemented: val |= 1 << 24
            val |= (self.interrupt_message_number & 0x1f) << 25
            return val
        elif reg == 1:
            # Device capabilities
            val = self.max_payload_size_supported & 0x7
            val |= (self.phantom_functions_supported & 0x3) << 3
            if self.extended_tag_supported: val |= 1 << 5
            val |= (self.endpoint_l0s_acceptable_latency & 0x7) << 6
            val |= (self.endpoint_l1_acceptable_latency & 7) << 9
            if self.role_based_error_reporting: val |= 1 << 15
            val |= (self.captured_slot_power_limit_value & 0xff) << 18
            val |= (self.captured_slot_power_limit_scale & 0x3) << 26
            if self.function_level_reset_capability: val |= 1 << 28
            return val
        elif reg ==  2:
            val = 0
            # Device control
            if self.correctable_error_reporting_enable: val |= 1 << 0
            if self.non_fatal_error_reporting_enable: val |= 1 << 1
            if self.fatal_error_reporting_enable: val |= 1 << 2
            if self.unsupported_request_reporting_enable: val |= 1 << 3
            if self.enable_relaxed_ordering: val |= 1 << 4
            val |= (self.max_payload_size & 0x7) << 5
            if self.extended_tag_field_enable: val |= 1 << 8
            if self.phantom_functions_enable: val |= 1 << 9
            if self.aux_power_pm_enable: val |= 1 << 10
            if self.enable_no_snoop: val |= 1 << 11
            val |= (self.max_read_request_size & 0x7) << 12
            # Device status
            if self.correctable_error_detected: val |= 1 << 16
            if self.nonfatal_error_detected: val |= 1 << 17
            if self.fatal_error_detected: val |= 1 << 18
            if self.unsupported_request_detected: val |= 1 << 19
            if self.aux_power_detected: val |= 1 << 20
            if self.transactions_pending: val |= 1 << 21
            return val
        elif reg ==  3:
            # Link capabilities
            val = self.max_link_speed & 0xf
            val |= (self.max_link_width & 0x3f) >> 4
            val |= (self.aspm_support & 0x3) >> 10
            val |= (self.l0s_exit_latency & 0x7) >> 12
            val |= (self.l1_exit_latency & 0x7) >> 15
            if self.clock_power_management: val |= 1 << 18
            if self.surprise_down_error_reporting_capability: val |= 1 << 19
            if self.data_link_layer_link_active_reporting_capable: val |= 1 << 20
            if self.link_bandwidth_notification_capability: val |= 1 << 21
            if self.aspm_optionality_compliance: val |= 1 << 22
            val |= (self.port_number & 0xff) << 24
            return val
        elif reg ==  4:
            # Link control
            val = self.aspm_control & 0x3
            if self.read_completion_boundary: val |= 1 << 3
            if self.link_disable: val |= 1 << 4
            if self.common_clock_configuration: val |= 1 << 6
            if self.extended_synch: val |= 1 << 7
            if self.enable_clock_power_management: val |= 1 << 8
            if self.hardware_autonomous_width_disable: val |= 1 << 9
            if self.link_bandwidth_management_interrupt_enable: val |= 1 << 10
            if self.link_autonomous_bandwidth_interrupt_enable: val |= 1 << 11
            # Link status
            val |= (self.current_link_speed & 0xf) << 16
            val |= (self.negotiated_link_width & 0x3f) << 20
            if self.link_training: val |= 1 << 27
            if self.slot_clock_configuration: val |= 1 << 28
            if self.data_link_layer_link_active: val |= 1 << 29
            if self.link_bandwidth_management_status: val |= 1 << 30
            if self.link_autonomous_bandwidth_status: val |= 1 << 31
            return val
        elif reg ==  5:
            # Slot capabilities
            val = 0
            if self.attention_button_present: val |= 1
            if self.power_controller_present: val |= 1 << 1
            if self.mrl_sensor_present: val |= 1 << 2
            if self.attention_indicator_present: val |= 1 << 3
            if self.power_indicator_present: val |= 1 << 4
            if self.hot_plug_surprise: val |= 1 << 5
            if self.hot_plug_capable: val |= 1 << 6
            val |= (self.slot_power_limit_value & 0xff) << 7
            val |= (self.slot_power_limit_scale & 0x3) << 15
            if self.electromechanical_interlock_present: val |= 1 << 17
            if self.no_command_completed_support: val |= 1 << 18
            val |= (self.physical_slot_number & 0x1fff) << 19
            return val
        elif reg ==  6:
            # Slot control
            val = 0
            if self.attention_button_pressed_enable: val |= 1 << 0
            if self.power_fault_detected_enable: val |= 1 << 1
            if self.mrl_sensor_changed_enable: val |= 1 << 2
            if self.presence_detect_changed_enable: val |= 1 << 3
            if self.command_completed_interrupt_enable: val |= 1 << 4
            if self.hot_plug_interrupt_enable: val |= 1 << 5
            val |= (self.attention_indicator_control & 0x3) << 6
            val |= (self.power_indicator_control & 0x3) << 8
            if self.power_controller_control: val |= 1 << 10
            if self.electromechanical_interlock_control: val |= 1 << 11
            if self.data_link_layer_state_changed_enable: val |= 1 << 12
            # Slot status
            if self.attention_button_pressed: val |= 1 << 16
            if self.power_fault_detected: val |= 1 << 17
            if self.mrl_sensor_changed: val |= 1 << 18
            if self.presence_detect_changed: val |= 1 << 19
            if self.command_completed: val |= 1 << 20
            if self.mrl_sensor_state: val |= 1 << 21
            if self.presence_detect_state: val |= 1 << 22
            if self.electromechanical_interlock_status: val |= 1 << 23
            if self.data_link_layer_state_changed: val |= 1 << 24
            return val
        elif reg ==  7:
            # Root control
            val = 0
            if self.system_error_on_correctable_error_enable: val |= 1 << 0
            if self.system_error_on_non_fatal_error_enable: val |= 1 << 1
            if self.system_error_on_fatal_error_enable: val |= 1 << 2
            if self.pme_interrupt_enable: val |= 1 << 3
            if self.crs_software_visibility_enable: val |= 1 << 4
            # Root capabilities
            if self.crs_software_visibility: val |= 1 << 16
            return val
        elif reg ==  8:
            # Root status
            val = self.pme_requester_id & 0xffff
            if self.pme_status: val |= 1 << 16
            if self.pme_pending: val |= 1 << 17
            return val
        elif reg ==  9:
            # Device capabilities 2
            val = self.completion_timeout_ranges_supported & 0xf
            if self.completion_timeout_disable_supported: val |= 1 << 4
            if self.ari_forwarding_supported: val |= 1 << 5
            if self.atomic_op_forwarding_supported: val |= 1 << 6
            if self.atomic_op_32_bit_completer_supported: val |= 1 << 7
            if self.atomic_op_64_bit_completer_supported: val |= 1 << 8
            if self.cas_128_bit_completer_supported: val |= 1 << 9
            if self.no_ro_enabled_pr_pr_passing: val |= 1 << 10
            if self.ltr_mechanism_supported: val |= 1 << 11
            val |= (self.tph_completer_supported & 0x3) << 12
            val |= (self.obff_supported & 0x3) << 18
            if self.extended_fmt_field_supported: val |= 1 << 20
            if self.end_end_tlp_prefix_supported: val |= 1 << 21
            val |= (self.max_end_end_tlp_prefix & 0x3) << 22
            return val
        elif reg == 10:
            # Device control 2
            val = self.completion_timeout_value & 0xf
            if self.completion_timeout_disable: val |= 1 << 4
            if self.ari_forwarding_enable: val |= 1 << 5
            if self.atomic_op_requester_enable: val |= 1 << 6
            if self.atomic_op_egress_blocking: val |= 1 << 7
            if self.ido_request_enable: val |= 1 << 8
            if self.ido_completion_enable: val |= 1 << 9
            if self.ltr_mechanism_enable: val |= 1 << 10
            val |= (self.obff_enable & 0x3) << 13
            if self.end_end_tlp_prefix_blocking: val |= 1 << 15
            # Device status 2
            return val
        elif reg == 11:
            # Link capabilities 2
            val = (self.supported_link_speeds & 0x7f) << 1
            if self.crosslink_supported: val |= 1 << 8
            return val
        elif reg == 12:
            # Link control 2
            val = self.target_link_speed & 0xf
            if self.enter_compliance: val |= 1 << 4
            if self.hardware_autonomous_speed_disable: val |= 1 << 5
            if self.selectable_de_emphasis: val |= 1 << 6
            val |= (self.transmit_margin & 0x7) << 7
            if self.enter_modified_compliance: val |= 1 << 10
            if self.compliance_sos: val |= 1 << 11
            val |= (self.compliance_preset_de_emphasis & 0xf) << 12
            # Link status 2
            if self.current_de_emphasis_level: val |= 1 << 16
            if self.equalization_complete: val |= 1 << 17
            if self.equalization_phase_1_successful: val |= 1 << 18
            if self.equalization_phase_2_successful: val |= 1 << 19
            if self.equalization_phase_3_successful: val |= 1 << 20
            if self.link_equalization_request: val |= 1 << 21
            return val
        else:
            return 0

    def write_pcie_cap_register(self, reg, data, mask):
        if reg ==  2:
            # Device control
            if mask & 0x1: self.correctable_error_reporting_enable = (data & 1 << 0 != 0)
            if mask & 0x1: self.non_fatal_error_reporting_enable = (data & 1 << 1 != 0)
            if mask & 0x1: self.fatal_error_reporting_enable = (data & 1 << 2 != 0)
            if mask & 0x1: self.unsupported_request_reporting_enable = (data & 1 << 3 != 0)
            if mask & 0x1: self.enable_relaxed_ordering = (data & 1 << 4 != 0)
            if mask & 0x1: self.max_payload_size = (data >> 5) & 0x7
            if mask & 0x2: self.extended_tag_field_enable = (data & 1 << 8 != 0)
            if mask & 0x2: self.phantom_functions_enable = (data & 1 << 9 != 0)
            if mask & 0x2: self.aux_power_pm_enable = (data & 1 << 10 != 0)
            if mask & 0x2: self.enable_no_snoop = (data & 1 << 11 != 0)
            if mask & 0x2: self.max_read_request_size = (data >> 12) & 0x7
            if mask & 0x2 and data & 1 << 15: self.initiate_function_level_reset()
            # Device status
            if mask & 0x4 and data & 1 << 16: self.correctable_error_detected = False
            if mask & 0x4 and data & 1 << 17: self.nonfatal_error_detected = False
            if mask & 0x4 and data & 1 << 18: self.fatal_error_detected = False
            if mask & 0x4 and data & 1 << 19: self.unsupported_request_detected = False
            if mask & 0x4 and data & 1 << 20: self.aux_power_detected = False
            if mask & 0x4 and data & 1 << 21: self.transactions_pending = False
        elif reg ==  4:
            # Link control
            if mask & 0x1: self.aspm_control = data & 3
            if mask & 0x1: self.read_completion_boundary = (data & 1 << 4 != 0)
            if mask & 0x1 and data & 1 << 5: self.initiate_retrain_link()
            if mask & 0x1: self.common_clock_configuration = (data & 1 << 6 != 0)
            if mask & 0x1: self.extended_synch = (data & 1 << 7 != 0)
            if mask & 0x2: self.enable_clock_power_management = (data & 1 << 8 != 0)
            if mask & 0x2: self.hardware_autonomous_width_disable = (data & 1 << 9 != 0)
            if mask & 0x2: self.link_bandwidth_management_interrupt_enable = (data & 1 << 10 != 0)
            if mask & 0x2: self.link_autonomous_bandwidth_interrupt_enable = (data & 1 << 11 != 0)
            # Link status
            if mask & 0x8 and data & 1 << 30: self.link_bandwidth_management_status = False
            if mask & 0x8 and data & 1 << 31: self.link_autonomous_bandwidth_status = False
        elif reg ==  6:
            # Slot control
            if mask & 0x1: self.attention_button_pressed_enable = (data & 1 << 0 != 0)
            if mask & 0x1: self.power_fault_detected_enable = (data & 1 << 1 != 0)
            if mask & 0x1: self.mrl_sensor_changed_enable = (data & 1 << 2 != 0)
            if mask & 0x1: self.presence_detect_changed_enable = (data & 1 << 3 != 0)
            if mask & 0x1: self.command_completed_interrupt_enable = (data & 1 << 4 != 0)
            if mask & 0x1: self.hot_plug_interrupt_enable = (data & 1 << 5 != 0)
            if mask & 0x1: self.attention_indicator_control = (data >> 6) & 0x3
            if mask & 0x2: self.power_indicator_control = (data >> 8) & 0x3
            if mask & 0x2: self.power_controller_control = (data & 1 << 10 != 0)
            if mask & 0x2: self.electromechanical_interlock_control = (data & 1 << 11 != 0)
            if mask & 0x2: self.data_link_layer_state_changed_enable = (data & 1 << 12 != 0)
            # Slot status
            if mask & 0x4 and data & 1 << 16: self.attention_button_pressed = False
            if mask & 0x4 and data & 1 << 17: self.power_fault_detected = False
            if mask & 0x4 and data & 1 << 18: self.mrl_sensor_changed = False
            if mask & 0x4 and data & 1 << 19: self.presence_detect_changed = False
            if mask & 0x4 and data & 1 << 20: self.command_completed = False
            if mask & 0x8 and data & 1 << 24: self.data_link_layer_state_changed = False
        elif reg ==  7:
            # Root control
            if mask & 0x1: self.system_error_on_correctable_error_enable = (data & 1 << 0 != 0)
            if mask & 0x1: self.system_error_on_non_fatal_error_enable = (data & 1 << 1 != 0)
            if mask & 0x1: self.system_error_on_fatal_error_enable = (data & 1 << 2 != 0)
            if mask & 0x1: self.pme_interrupt_enable = (data & 1 << 3 != 0)
            if mask & 0x1: self.crs_software_visibility_enable = (data & 1 << 4 != 0)
        elif reg ==  8:
            # Root status
            if mask & 0x4 and data & 1 << 16: self.pme_status = False
        elif reg == 10:
            # Device control 2
            if mask & 0x1: self.completion_timeout_value = data & 0xf
            if mask & 0x1: self.completion_timeout_disable = (data & 1 << 4 != 0)
            if mask & 0x1: self.ari_forwarding_enable = (data & 1 << 5 != 0)
            if mask & 0x1: self.atomic_op_requester_enable = (data & 1 << 6 != 0)
            if mask & 0x1: self.atomic_op_egress_blocking = (data & 1 << 7 != 0)
            if mask & 0x2: self.ido_request_enable = (data & 1 << 8 != 0)
            if mask & 0x2: self.ido_completion_enable = (data & 1 << 9 != 0)
            if mask & 0x2: self.ltr_mechanism_enable = (data & 1 << 10 != 0)
            if mask & 0x2: self.obff_enable = (data >> 13) & 0x3
            if mask & 0x2: self.end_end_tlp_prefix_blocking = (data & 1 << 15 != 0)
            # Device status 2
        elif reg == 12:
            # Link control 2
            if mask & 0x1: self.target_link_speed = data & 0xf
            if mask & 0x1: self.enter_compliance = (data & 1 << 4 != 0)
            if mask & 0x1: self.hardware_autonomous_speed_disable = (data & 1 << 5 != 0)
            if mask & 0x1: self.transmit_margin = self.transmit_margin & 0x6 | (data >> 7) & 0x1
            if mask & 0x2: self.transmit_margin = self.transmit_margin & 0x1 | (data >> 7) & 0x6
            if mask & 0x2: self.enter_modified_compliance = (data & 1 << 10 != 0)
            if mask & 0x2: self.compliance_sos = (data & 1 << 11 != 0)
            if mask & 0x2: self.compliance_preset_de_emphasis = (data >> 12) & 0xff
            # Link status 2
            if self.link_equalization_request: val |= 1 << 21

    def initiate_function_level_reset(self):
        pass

    def initiate_retrain_link(self):
        pass


class MSICapability(object):
    def __init__(self, *args, **kwargs):
        super(MSICapability, self).__init__(*args, **kwargs)

        # MSI Capability Registers
        self.msi_enable = False
        self.msi_multiple_message_capable = 0
        self.msi_multiple_message_enable = 0
        self.msi_64bit_address_capable = 0
        self.msi_per_vector_mask_capable = 0
        self.msi_message_address = 0
        self.msi_message_data = 0
        self.msi_mask_bits = 0
        self.msi_pending_bits = 0

        self.register_capability(MSI_CAP_ID, MSI_CAP_LEN, self.read_msi_cap_register, self.write_msi_cap_register)

    """
    MSI Capability (32 bit)

    31                                                                  0
    +---------------------------------+----------------+----------------+
    |         Message Control         |    Next Cap    |     Cap ID     |   0   0x00
    +---------------------------------+----------------+----------------+
    |                          Message Address                          |   1   0x04
    +---------------------------------+---------------------------------+
    |                                 |           Message Data          |   2   0x08
    +---------------------------------+---------------------------------+

    MSI Capability (64 bit)

    31                                                                  0
    +---------------------------------+----------------+----------------+
    |         Message Control         |    Next Cap    |     Cap ID     |   0   0x00
    +---------------------------------+----------------+----------------+
    |                          Message Address                          |   1   0x04
    +-------------------------------------------------------------------+
    |                       Message Upper Address                       |   2   0x08
    +---------------------------------+---------------------------------+
    |                                 |           Message Data          |   3   0x0C
    +---------------------------------+---------------------------------+

    MSI Capability (32 bit with per-vector masking)

    31                                                                  0
    +---------------------------------+----------------+----------------+
    |         Message Control         |    Next Cap    |     Cap ID     |   0   0x00
    +---------------------------------+----------------+----------------+
    |                          Message Address                          |   1   0x04
    +-------------------------------------------------------------------+
    |                                 |           Message Data          |   2   0x08
    +---------------------------------+---------------------------------+
    |                             Mask Bits                             |   3   0x0C
    +-------------------------------------------------------------------+
    |                           Pending Bits                            |   4   0x10
    +-------------------------------------------------------------------+

    MSI Capability (64 bit with per-vector masking)

    31                                                                  0
    +---------------------------------+----------------+----------------+
    |         Message Control         |    Next Cap    |     Cap ID     |   0   0x00
    +---------------------------------+----------------+----------------+
    |                          Message Address                          |   1   0x04
    +-------------------------------------------------------------------+
    |                       Message Upper Address                       |   2   0x08
    +---------------------------------+---------------------------------+
    |                                 |           Message Data          |   3   0x0C
    +---------------------------------+---------------------------------+
    |                             Mask Bits                             |   4   0x10
    +-------------------------------------------------------------------+
    |                           Pending Bits                            |   5   0x14
    +-------------------------------------------------------------------+
    """
    def read_msi_cap_register(self, reg):
        if reg == 0:
            # Message control
            val = 0x00000000
            if self.msi_enable: val |= 1 << 16
            val |= (self.msi_multiple_message_capable & 0x7) << 17
            val |= (self.msi_multiple_message_enable & 0x7) << 20
            if self.msi_64bit_address_capable: val |= 1 << 23
            if self.msi_per_vector_mask_capable: val |= 1 << 24
            return val
        elif reg == 1:
            # Message address
            return self.msi_message_address & 0xfffffffc
        elif reg == 2 and self.msi_64bit_address_capable:
            # Message upper address
            return (self.msi_message_address >> 32) & 0xffffffff
        elif reg == (3 if self.msi_64bit_address_capable else 2):
            # Message data
            return self.msi_message_data & 0xffff
        elif reg == (4 if self.msi_64bit_address_capable else 3) and self.msi_per_vector_mask_capable:
            # Mask bits
            return self.msi_mask_bits & 0xffffffff
        elif reg == (5 if self.msi_64bit_address_capable else 4) and self.msi_per_vector_mask_capable:
            # Pending bits
            return self.msi_pending_bits & 0xffffffff

    def write_msi_cap_register(self, reg, data, mask):
        if reg == 0:
            # Message control
            if mask & 0x4: self.msi_enable = (data & 1 << 16 != 0)
            if mask & 0x4: self.msi_multiple_message_enable = (data >> 20) & 0x7
        elif reg == 1:
            # Message address
            self.msi_message_address = byte_mask_update(self.msi_message_address, mask, data) & 0xfffffffffffffffc
        elif reg == 2 and self.msi_64bit_address_capable:
            # Message upper address
            self.msi_message_address = byte_mask_update(self.msi_message_address, mask << 4, data << 32) & 0xfffffffffffffffc
        elif reg == (3 if self.msi_64bit_address_capable else 2):
            # Message data
            self.msi_message_data = byte_mask_update(self.msi_message_data, mask & 0x3, data) & 0xffff
        elif reg == (4 if self.msi_64bit_address_capable else 3) and self.msi_per_vector_mask_capable:
            # Mask bits
            self.msi_mask_bits = byte_mask_update(self.msi_mask_bits, mask, data) & 0xffffffff

    def issue_msi_interrupt(self, number=0, attr=0, tc=0):
        if not self.msi_enable:
            print("MSI disabled")
            return
        if number < 0 or number >= 2**self.msi_multiple_message_enable or number >= 2**self.msi_multiple_message_capable:
            print("MSI message number out of range")
            return

        data = self.msi_message_data & ~(2**self.msi_multiple_message_enable-1) | number
        yield from self.mem_write(self.msi_message_address, struct.pack('<L', data), attr=attr, tc=tc)


class MSIXCapability(object):
    def __init__(self, *args, **kwargs):
        super(MSIXCapability, self).__init__(*args, **kwargs)

        # MSI-X Capability Registers
        self.msix_table_size = 0
        self.msix_function_mask = False
        self.msix_enable = False
        self.msix_table_bar_indicator_register = 0
        self.msix_table_offset = 0
        self.msix_pba_bar_indicator_register = 0
        self.msix_pba_offset = 0

        self.register_capability(MSIX_CAP_ID, MSIX_CAP_LEN, self.read_msix_cap_register, self.write_msix_cap_register)

    """
    MSI-X Capability

    31                                                                  0
    +---------------------------------+----------------+----------------+
    |         Message Control         |    Next Cap    |     Cap ID     |   0   0x00
    +---------------------------------+----------------+----------+-----+
    |                         Table Offset                        | BIR |   1   0x04
    +-------------------------------------------------------------+-----+
    |                          PBA Offset                         | BIR |   2   0x08
    +-------------------------------------------------------------+-----+
    """
    def read_msix_cap_register(self, reg):
        if reg == 0:
            # Message control
            val = (self.msix_table_size & 0x7ff) << 16
            if self.msix_function_mask: val |= 1 << 30
            if self.msix_enable: val |= 1 << 31
            return val
        elif reg == 1:
            # Table offset and BIR
            val = self.msix_table_bar_indicator_register & 0x7
            val |= self.msix_table_offset & 0xfffffff8
            return val
        elif reg == 2:
            # Pending bit array offset and BIR
            val = self.msix_pba_bar_indicator_register & 0x7
            val |= self.msix_pba_offset & 0xfffffff8
            return val

    def write_msix_cap_register(self, reg, data, mask):
        if reg == 0:
            # Message control
            if mask & 0x8: self.msix_function_mask = (data & 1 << 30 != 0)
            if mask & 0x8: self.msix_enable = (data & 1 << 31 != 0)

    def issue_msix_interrupt(self, addr, data, attr=0, tc=0):
        if not self.msix_enable:
            print("MSI-X disabled")
            return

        yield from self.mem_write(addr, struct.pack('<L', data), attr=attr, tc=tc)


class Function(PMCapability, PCIECapability):
    """PCIe function, implements config TLP handling"""
    def __init__(self, *args, **kwargs):
        self.bus_num = 0
        self.device_num = 0
        self.function_num = 0

        self.upstream_tx_handler = None

        self.desc = "Function"

        self.current_tag = 0

        self.rx_cpl_queues = [[] for k in range(256)]
        self.rx_cpl_sync = [Signal(False) for k in range(256)]

        self.rx_tlp_handler = {}

        self.capabilities = PcieCapList()
        self.ext_capabilities = PcieExtCapList()

        # configuration registers
        self.vendor_id = 0
        self.device_id = 0
        # command register
        self.bus_master_enable = False
        self.parity_error_response = False
        self.serr_enable = False
        self.interrupt_disable = False
        # status register
        self.interrupt_status = False
        self.capabilities_list = True
        self.master_data_parity_error = False
        self.signaled_target_abort = False
        self.received_target_abort = False
        self.received_master_abort = False
        self.signaled_system_error = False
        self.detected_parity_error = False
        self.rev_id = 0
        self.class_code = 0
        self.cache_ln = 0
        self.lat_timer = 0
        self.header_type = 0
        self.bist = 0
        self.bar = []
        self.bar_mask = []
        self.expansion_rom_addr = 0
        self.cap_ptr = 0
        self.intr_pin = 0
        self.intr_line = 0

        self.read_completion_boundary = 128

        self.register_rx_tlp_handler(TLP_CFG_READ_0, self.handle_config_0_tlp)
        self.register_rx_tlp_handler(TLP_CFG_WRITE_0, self.handle_config_0_tlp)

        super(Function, self).__init__(*args, **kwargs)

    def get_id(self):
        return PcieId(self.bus_num, self.device_num, self.function_num)

    def get_desc(self):
        return "%02x:%02x.%x %s" % (self.bus_num, self.device_num, self.function_num, self.desc)

    """
    Common config space

    31                                                                  0
    +---------------------------------+---------------------------------+
    |            Device ID            |            Vendor ID            |   0   0x00
    +---------------------------------+---------------------------------+
    |             Status              |             Command             |   1   0x04
    +---------------------------------+----------------+----------------+
    |                    Class Code                    |  Revision ID   |   2   0x08
    +----------------+----------------+----------------+----------------+
    |      BIST      |  Header Type   |    Primary     |   Cache Line   |   3   0x0C
    |                |                | Latency Timer  |      Size      |
    +----------------+----------------+----------------+----------------+
    |                                                                   |   4   0x10
    +-------------------------------------------------------------------+
    |                                                                   |   5   0x14
    +-------------------------------------------------------------------+
    |                                                                   |   6   0x18
    +-------------------------------------------------------------------+
    |                                                                   |   7   0x1C
    +-------------------------------------------------------------------+
    |                                                                   |   8   0x20
    +-------------------------------------------------------------------+
    |                                                                   |   9   0x24
    +-------------------------------------------------------------------+
    |                                                                   |  10   0x28
    +-------------------------------------------------------------------+
    |                                                                   |  11   0x2C
    +-------------------------------------------------------------------+
    |                                                                   |  12   0x30
    +--------------------------------------------------+----------------+
    |                                                  |    Cap Ptr     |  13   0x34
    +--------------------------------------------------+----------------+
    |                                                                   |  14   0x38
    +---------------------------------+----------------+----------------+
    |                                 |    Int Pin     |    Int Line    |  15   0x3C
    +---------------------------------+----------------+----------------+
    """
    def read_config_register(self, reg):
        if   reg ==  0: return (self.device_id << 16) | self.vendor_id
        #elif reg ==  1: return (self.status << 16) | self.command
        elif reg ==  1:
            val = 0
            # command
            if self.bus_master_enable: val |= 1 << 2
            if self.parity_error_response: val |= 1 << 6
            if self.serr_enable: val |= 1 << 8
            if self.interrupt_disable: val |= 1 << 10
            # status
            if self.interrupt_status: val |= 1 << 19
            if self.capabilities_list: val |= 1 << 20
            if self.master_data_parity_error: val |= 1 << 24
            if self.signaled_target_abort: val |= 1 << 27
            if self.received_target_abort: val |= 1 << 28
            if self.received_master_abort: val |= 1 << 29
            if self.signaled_system_error: val |= 1 << 30
            if self.detected_parity_error: val |= 1 << 31
            return val
        elif reg ==  2: return (self.class_code << 8) | self.rev_id
        elif reg ==  3: return (self.bist << 24) | (self.header_type << 16) | (self.lat_timer << 8) | self.cache_ln
        elif reg == 13: return self.cap_ptr
        elif reg == 15: return (self.intr_pin << 8) | self.intr_line
        elif 16 <= reg < 256: return self.read_capability_register(reg)
        elif 256 <= reg < 4096: return self.read_extended_capability_register(reg)
        else:           return 0

    def write_config_register(self, reg, data, mask):
        if   reg ==  1:
            # command
            if mask & 0x1: self.bus_master_enable = (data & 1 << 2 != 0)
            if mask & 0x1: self.parity_error_response = (data & 1 << 6 != 0)
            if mask & 0x2: self.serr_enable = (data & 1 << 8 != 0)
            if mask & 0x2: self.interrupt_disable = (data & 1 << 10 != 0)
            # status
            if mask & 0x8 and data & 1 << 24: self.master_data_parity_error = False
            if mask & 0x8 and data & 1 << 27: self.signaled_target_abort = False
            if mask & 0x8 and data & 1 << 28: self.received_target_abort = False
            if mask & 0x8 and data & 1 << 29: self.received_master_abort = False
            if mask & 0x8 and data & 1 << 30: self.signaled_system_error = False
            if mask & 0x8 and data & 1 << 31: self.detected_parity_error = False
        elif reg ==  3:
            self.cache_ln = byte_mask_update(self.cache_ln, mask & 1, data)
            self.lat_timer = byte_mask_update(self.lat_timer, (mask >> 1) & 1, data >> 8)
            self.bist = byte_mask_update(self.bist, (mask >> 3) & 1, data >> 24)
        elif reg == 15:
            self.intr_line = byte_mask_update(self.intr_line, mask & 1, data)
            self.intr_pin = byte_mask_update(self.intr_pin, (mask >> 1) & 1, data >> 8)
        elif 16 <= reg < 256: self.write_capability_register(reg, data, mask)
        elif 256 <= reg < 4096: self.write_extended_capability_register(reg, data, mask)

    def read_capability_register(self, reg):
        return self.capabilities.read_register(reg)

    def write_capability_register(self, reg, data, mask):
        self.capabilities.write_register(reg, data, mask)

    def register_capability(self, cap_id, length=None, read=None, write=None, offset=None):
        self.capabilities.register(cap_id, 0, length, read, write, offset)
        if self.capabilities.list:
            self.cap_ptr = self.capabilities.list[0].offset*4
        else:
            self.cap_ptr = 0

    def read_extended_capability_register(self, reg):
        return self.ext_capabilities.read_register(reg)

    def write_extended_capability_register(self, reg, data, mask):
        self.ext_capabilities.write_register(reg, data, mask)

    def register_extended_capability(self, cap_id, cap_ver, length=None, read=None, write=None, offset=None):
        self.ext_capabilities.register(cap_id, cap_ver, length, read, write, offset)

    def configure_bar(self, idx, size, ext=False, prefetch=False, io=False):
        mask = 2**math.ceil(math.log(size, 2))-1

        if idx >= len(self.bar) or (ext and idx+1 >= len(self.bar)):
            raise Exception("BAR index out of range")

        if io:
            self.bar[idx] = 1
            self.bar_mask[idx] = 0xfffffffc & ~mask
        else:
            self.bar[idx] = 0
            self.bar_mask[idx] = 0xfffffff0 & ~mask

            if ext:
                self.bar[idx] |= 4
                self.bar[idx+1] = 0
                self.bar_mask[idx+1] = 0xffffffff & (~mask >> 32)

            if prefetch:
                self.bar[idx] |= 8

    def match_bar(self, addr, io=False):
        m = []
        bar = 0
        while bar < len(self.bar):
            bar_val = self.bar[bar]
            bar_mask = self.bar_mask[bar]

            orig_bar = bar
            bar += 1

            if bar_mask == 0:
                # unimplemented BAR
                continue

            if bar_val & 1:
                # IO BAR

                if io and addr & bar_mask == bar_val & bar_mask:
                    m.append((orig_bar, addr & ~bar_mask))

            else:
                # Memory BAR

                if bar_val & 4:
                    # 64 bit BAR

                    if bar >= len(self.bar):
                        raise Exception("Final BAR marked as 64 bit, but no extension BAR available")

                    bar_val |= self.bar[bar] << 32
                    bar_mask |= self.bar_mask[bar] << 32

                    bar += 1

                if not io and addr & bar_mask == bar_val & bar_mask:
                    m.append((orig_bar, addr & ~bar_mask))

        return m

    def upstream_send(self, tlp):
        # logging
        print("[%s] Sending upstream TLP: %s" % (highlight(self.get_desc()), repr(tlp)))
        assert tlp.check()
        if self.upstream_tx_handler is None:
            raise Exception("Transmit handler not set")
        yield from self.upstream_tx_handler(tlp)

    def send(self, tlp):
        yield from self.upstream_send(tlp)

    def upstream_recv(self, tlp):
        # logging
        print("[%s] Got downstream TLP: %s" % (highlight(self.get_desc()), repr(tlp)))
        assert tlp.check()
        yield from self.handle_tlp(tlp)

    def handle_tlp(self, tlp):
        if (tlp.fmt_type == TLP_CPL or tlp.fmt_type == TLP_CPL_DATA or
                tlp.fmt_type == TLP_CPL_LOCKED or tlp.fmt_type == TLP_CPL_LOCKED_DATA):
            self.rx_cpl_queues[tlp.tag].append(tlp)
            self.rx_cpl_sync[tlp.tag].next = not self.rx_cpl_sync[tlp.tag]
        elif tlp.fmt_type in self.rx_tlp_handler:
            yield self.rx_tlp_handler[tlp.fmt_type](tlp)
        else:
            raise Exception("Unhandled TLP")

    def register_rx_tlp_handler(self, fmt_type, func):
        self.rx_tlp_handler[fmt_type] = func

    def recv_cpl(self, tag, timeout=0):
        queue = self.rx_cpl_queues[tag]
        sync = self.rx_cpl_sync[tag]

        if timeout:
            yield sync, delay(timeout)
        else:
            yield sync

        if queue:
            return queue.pop(0)

        return None

    def get_free_tag(self):
        tag_count = 256 if self.extended_tag_field_enable else 32

        for k in range(tag_count):
            self.current_tag = (self.current_tag + 1) % tag_count
            if not self.rx_cpl_queues[self.current_tag]:
                return self.current_tag

        return None

    def handle_config_0_tlp(self, tlp):
        if tlp.dest_id.device == self.device_num and tlp.dest_id.function == self.function_num:
            # logging
            print("[%s] Config type 0 for me" % (highlight(self.get_desc())))

            # capture address information
            self.bus_num = tlp.dest_id.bus

            # prepare completion TLP
            cpl = TLP()

            # perform operation
            if tlp.fmt_type == TLP_CFG_READ_0:
                cpl.set_completion_data(tlp, self.get_id())
                cpl.data = [self.read_config_register(tlp.register_number)]
                cpl.byte_count = 4
                cpl.length = 1
            elif tlp.fmt_type == TLP_CFG_WRITE_0:
                cpl.set_completion(tlp, self.get_id())
                self.write_config_register(tlp.register_number, tlp.data[0], tlp.first_be)

            # logging
            print("[%s] Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
            yield from self.upstream_send(cpl)
        else:
            # error
            pass

    def io_read(self, addr, length, timeout=0):
        n = 0
        data = b''

        if not self.bus_master_enable:
            print("Bus mastering not enabled")
            return None

        while n < length:
            tlp = TLP()
            tlp.fmt_type = TLP_IO_READ
            tlp.requester_id = self.get_id()
            tlp.tag = self.get_free_tag()

            first_pad = addr % 4
            byte_length = min(length-n, 4-first_pad)
            tlp.set_be(addr, byte_length)

            yield from self.send(tlp)
            cpl = yield from self.recv_cpl(tlp.tag, timeout)

            if not cpl:
                raise Exception("Timeout")
            if cpl.status != CPL_STATUS_SC:
                raise Exception("Unsuccessful completion")
            else:
                assert cpl.length == 1
                d = struct.pack('<L', cpl.data[0])

            data += d[first_pad:]

            n += byte_length
            addr += byte_length

        return data[:length]

    def io_read_words(self, addr, count, ws=2, timeout=0, attr=0, tc=0):
        assert ws in (1, 2, 4, 8)
        data = yield from self.io_read(addr, count*ws, timeout, attr, tc)
        words = []
        for k in range(count):
            words.append(int.from_bytes(data[ws*k:ws*(k+1)], 'little'))
        return words

    def io_read_dwords(self, addr, count, timeout=0, attr=0, tc=0):
        data = yield from self.io_read_words(addr, count, 4, timeout, attr, tc)
        return data

    def io_read_qwords(self, addr, count, timeout=0, attr=0, tc=0):
        data = yield from self.io_read_words(addr, count, 8, timeout, attr, tc)
        return data

    def io_read_byte(self, addr, timeout=0, attr=0, tc=0):
        data = yield from self.io_read(addr, 1, timeout, attr, tc)
        return data[0]

    def io_read_word(self, addr, timeout=0, attr=0, tc=0):
        data = yield from self.io_read_words(addr, 1, timeout=timeout, attr=attr, tc=tc)
        return data[0]

    def io_read_dword(self, addr, timeout=0, attr=0, tc=0):
        data = yield from self.io_read_dwords(addr, 1, timeout=timeout, attr=attr, tc=tc)
        return data[0]

    def io_read_qword(self, addr, timeout=0, attr=0, tc=0):
        data = yield from self.io_read_qwords(addr, 1, timeout=timeout, attr=attr, tc=tc)
        return data[0]

    def io_write(self, addr, data, timeout=0):
        n = 0

        if not self.bus_master_enable:
            print("Bus mastering not enabled")
            return

        while n < len(data):
            tlp = TLP()
            tlp.fmt_type = TLP_IO_WRITE
            tlp.requester_id = self.get_id()
            tlp.tag = self.get_free_tag()

            first_pad = addr % 4
            byte_length = min(len(data)-n, 4-first_pad)
            tlp.set_be_data(addr, data[n:n+byte_length])

            yield from self.send(tlp)
            cpl = yield from self.recv_cpl(tlp.tag, timeout)

            if not cpl:
                raise Exception("Timeout")
            if cpl.status != CPL_STATUS_SC:
                raise Exception("Unsuccessful completion")

            n += byte_length
            addr += byte_length

    def io_write_words(self, addr, data, ws=2, timeout=0, attr=0, tc=0):
        assert ws in (1, 2, 4, 8)
        words = data
        data = b''
        for w in words:
            data += w.to_bytes(ws, 'little')
        yield from self.io_write(addr, data, timeout, attr, tc)

    def io_write_dwords(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.io_write_words(addr, data, 4, timeout, attr, tc)

    def io_write_qwords(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.io_write_words(addr, data, 8, timeout, attr, tc)

    def io_write_byte(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.io_write(addr, [data], timeout, attr, tc)

    def io_write_word(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.io_write_words(addr, [data], timeout=timeout, attr=attr, tc=tc)

    def io_write_dword(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.io_write_dwords(addr, [data], timeout=timeout, attr=attr, tc=tc)

    def io_write_qword(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.io_write_qwords(addr, [data], timeout=timeout, attr=attr, tc=tc)

    def mem_read(self, addr, length, timeout=0, attr=0, tc=0):
        n = 0
        data = b''

        if not self.bus_master_enable:
            print("Bus mastering not enabled")
            return None

        while n < length:
            tlp = TLP()
            if addr > 0xffffffff:
                tlp.fmt_type = TLP_MEM_READ_64
            else:
                tlp.fmt_type = TLP_MEM_READ
            tlp.requester_id = self.get_id()
            tlp.tag = self.get_free_tag()
            tlp.attr = attr
            tlp.tc = tc

            first_pad = addr % 4
            byte_length = length-n
            byte_length = min(byte_length, (128 << self.max_read_request_size)-first_pad) # max read request size
            byte_length = min(byte_length, 0x1000 - (addr & 0xfff)) # 4k align
            tlp.set_be(addr, length)

            yield from self.send(tlp)

            m = 0

            while m < byte_length:
                cpl = yield from self.recv_cpl(tlp.tag, timeout)

                if not cpl:
                    raise Exception("Timeout")
                if cpl.status != CPL_STATUS_SC:
                    raise Exception("Unsuccessful completion")
                else:
                    assert cpl.byte_count+3+(cpl.lower_address&3) >= cpl.length*4
                    assert cpl.byte_count == byte_length - m

                    d = bytearray()

                    for k in range(cpl.length):
                        d.extend(struct.pack('<L', cpl.data[k]))

                    offset = cpl.lower_address&3
                    data += d[offset:offset+cpl.byte_count]

                m += len(d)-offset

            n += byte_length
            addr += byte_length

        return data

    def mem_read_words(self, addr, count, ws=2, timeout=0, attr=0, tc=0):
        assert ws in (1, 2, 4, 8)
        data = yield from self.mem_read(addr, count*ws, timeout, attr, tc)
        words = []
        for k in range(count):
            words.append(int.from_bytes(data[ws*k:ws*(k+1)], 'little'))
        return words

    def mem_read_dwords(self, addr, count, timeout=0, attr=0, tc=0):
        data = yield from self.mem_read_words(addr, count, 4, timeout, attr, tc)
        return data

    def mem_read_qwords(self, addr, count, timeout=0, attr=0, tc=0):
        data = yield from self.mem_read_words(addr, count, 8, timeout, attr, tc)
        return data

    def mem_read_byte(self, addr, timeout=0, attr=0, tc=0):
        data = yield from self.mem_read(addr, 1, timeout, attr, tc)
        return data[0]

    def mem_read_word(self, addr, timeout=0, attr=0, tc=0):
        data = yield from self.mem_read_words(addr, 1, timeout=timeout, attr=attr, tc=tc)
        return data[0]

    def mem_read_dword(self, addr, timeout=0, attr=0, tc=0):
        data = yield from self.mem_read_dwords(addr, 1, timeout=timeout, attr=attr, tc=tc)
        return data[0]

    def mem_read_qword(self, addr, timeout=0, attr=0, tc=0):
        data = yield from self.mem_read_qwords(addr, 1, timeout=timeout, attr=attr, tc=tc)
        return data[0]

    def mem_write(self, addr, data, timeout=0, attr=0, tc=0):
        n = 0

        if not self.bus_master_enable:
            print("Bus mastering not enabled")
            return

        while n < len(data):
            tlp = TLP()
            if addr > 0xffffffff:
                tlp.fmt_type = TLP_MEM_WRITE_64
            else:
                tlp.fmt_type = TLP_MEM_WRITE
            tlp.requester_id = self.get_id()
            tlp.attr = attr
            tlp.tc = tc

            first_pad = addr % 4
            byte_length = len(data)-n
            byte_length = min(byte_length, (128 << self.max_payload_size)-first_pad) # max payload size
            byte_length = min(byte_length, 0x1000 - (addr & 0xfff)) # 4k align
            tlp.set_be_data(addr, data[n:n+byte_length])

            yield from self.send(tlp)

            n += byte_length
            addr += byte_length

    def mem_write_words(self, addr, data, ws=2, timeout=0, attr=0, tc=0):
        assert ws in (1, 2, 4, 8)
        words = data
        data = b''
        for w in words:
            data += w.to_bytes(ws, 'little')
        yield from self.mem_write(addr, data, timeout, attr, tc)

    def mem_write_dwords(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.mem_write_words(addr, data, 4, timeout, attr, tc)

    def mem_write_qwords(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.mem_write_words(addr, data, 8, timeout, attr, tc)

    def mem_write_byte(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.mem_write(addr, [data], timeout, attr, tc)

    def mem_write_word(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.mem_write_words(addr, [data], timeout=timeout, attr=attr, tc=tc)

    def mem_write_dword(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.mem_write_dwords(addr, [data], timeout=timeout, attr=attr, tc=tc)

    def mem_write_qword(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.mem_write_qwords(addr, [data], timeout=timeout, attr=attr, tc=tc)


class Endpoint(Function):
    """PCIe endpoint function, implements endpoint config space"""
    def __init__(self, *args, **kwargs):
        super(Endpoint, self).__init__(*args, **kwargs)

        # configuration registers
        self.header_type = 0
        self.bar = [0]*6
        self.bar_mask = [0]*6
        self.cardbus_cis = 0
        self.subsystem_vendor_id = 0
        self.subsystem_id = 0

        self.pcie_device_type = 0

    """
    Endpoint (type 0) config space

    31                                                                  0
    +---------------------------------+---------------------------------+
    |            Device ID            |            Vendor ID            |   0   0x00
    +---------------------------------+---------------------------------+
    |             Status              |             Command             |   1   0x04
    +---------------------------------+----------------+----------------+
    |                    Class Code                    |  Revision ID   |   2   0x08
    +----------------+----------------+----------------+----------------+
    |      BIST      |  Header Type   |    Primary     |   Cache Line   |   3   0x0C
    |                |                | Latency Timer  |      Size      |
    +----------------+----------------+----------------+----------------+
    |                      Base Address Register 0                      |   4   0x10
    +-------------------------------------------------------------------+
    |                      Base Address Register 1                      |   5   0x14
    +-------------------------------------------------------------------+
    |                      Base Address Register 2                      |   6   0x18
    +-------------------------------------------------------------------+
    |                      Base Address Register 3                      |   7   0x1C
    +-------------------------------------------------------------------+
    |                      Base Address Register 4                      |   8   0x20
    +-------------------------------------------------------------------+
    |                      Base Address Register 5                      |   9   0x24
    +-------------------------------------------------------------------+
    |                       Cardbus CIS pointer                         |  10   0x28
    +---------------------------------+---------------------------------+
    |          Subsystem ID           |       Subsystem Vendor ID       |  11   0x2C
    +---------------------------------+---------------------------------+
    |                    Expansion ROM Base Address                     |  12   0x30
    +--------------------------------------------------+----------------+
    |                     Reserved                     |    Cap Ptr     |  13   0x34
    +--------------------------------------------------+----------------+
    |                             Reserved                              |  14   0x38
    +----------------+----------------+----------------+----------------+
    |    Max Lat     |    Min Gnt     |    Int Pin     |    Int Line    |  15   0x3C
    +----------------+----------------+----------------+----------------+
    """
    def read_config_register(self, reg):
        if   reg ==  4: return self.bar[0]
        elif reg ==  5: return self.bar[1]
        elif reg ==  6: return self.bar[2]
        elif reg ==  7: return self.bar[3]
        elif reg ==  8: return self.bar[4]
        elif reg ==  9: return self.bar[5]
        elif reg == 10: return self.cardbus_cis
        elif reg == 11: return (self.subsystem_id << 16) | self.subsystem_vendor_id
        elif reg == 12: return self.expansion_rom_addr
        elif reg == 13: return self.cap_ptr
        elif reg == 14: return 0 # reserved
        elif reg == 15: return (self.intr_pin << 8) | self.intr_line
        else:           return super(Endpoint, self).read_config_register(reg)

    def write_config_register(self, reg, data, mask):
        if   reg ==  4: self.bar[0] = byte_mask_update(self.bar[0], mask, data, self.bar_mask[0])
        elif reg ==  5: self.bar[1] = byte_mask_update(self.bar[1], mask, data, self.bar_mask[1])
        elif reg ==  6: self.bar[2] = byte_mask_update(self.bar[2], mask, data, self.bar_mask[2])
        elif reg ==  7: self.bar[3] = byte_mask_update(self.bar[3], mask, data, self.bar_mask[3])
        elif reg ==  8: self.bar[4] = byte_mask_update(self.bar[4], mask, data, self.bar_mask[4])
        elif reg ==  9: self.bar[5] = byte_mask_update(self.bar[5], mask, data, self.bar_mask[5])
        elif reg == 12: self.expansion_rom_addr = byte_mask_update(self.expansion_rom_addr, mask, data)
        elif reg == 15:
            self.intr_line = byte_mask_update(self.intr_line, mask & 1, data)
            self.intr_pin = byte_mask_update(self.intr_pin, (mask >> 1) & 1, data >> 8)
        else:           super(Endpoint, self).write_config_register(reg, data, mask)


class MemoryEndpoint(Endpoint):
    """PCIe endpoint function, implements BARs pointing to internal memory"""
    def __init__(self, *args, **kwargs):
        super(MemoryEndpoint, self).__init__(*args, **kwargs)

        self.regions = [None]*6
        self.bar_ptr = 0

        self.register_rx_tlp_handler(TLP_IO_READ, self.handle_io_read_tlp)
        self.register_rx_tlp_handler(TLP_IO_WRITE, self.handle_io_write_tlp)
        self.register_rx_tlp_handler(TLP_MEM_READ, self.handle_mem_read_tlp)
        self.register_rx_tlp_handler(TLP_MEM_READ_64, self.handle_mem_read_tlp)
        self.register_rx_tlp_handler(TLP_MEM_WRITE, self.handle_mem_write_tlp)
        self.register_rx_tlp_handler(TLP_MEM_WRITE_64, self.handle_mem_write_tlp)

    def add_region(self, size, read=None, write=None, ext=False, prefetch=False, io=False):
        if self.bar_ptr > 5 or (ext and self.bar_ptr > 4):
            raise Exception("No more BARs available")

        arr = None
        self.configure_bar(self.bar_ptr, size, ext, prefetch, io)
        if not read and not write:
            arr = bytearray(size)
            self.regions[self.bar_ptr] = arr
        else:
            self.regions[self.bar_ptr] = (read, write)
        if ext:
            self.bar_ptr += 2
        else:
            self.bar_ptr += 1
        return arr

    def add_io_region(self, size, read=None, write=None):
        return self.add_region(size, read, write, False, False, True)

    def add_mem_region(self, size, read=None, write=None):
        return self.add_region(size, read, write)

    def add_prefetchable_mem_region(self, size, read=None, write=None):
        return self.add_region(size, read, write, True, True)

    def read_region(self, region, addr, length):
        if not self.regions[region]:
            raise Exception("Invalid region")
        if type(self.regions[region]) is tuple:
            return self.regions[region][0](addr, length)
        else:
            return self.regions[region][addr:addr+length]

    def write_region(self, region, addr, data):
        if not self.regions[region]:
            raise Exception("Invalid region")
        if type(self.regions[region]) is tuple:
            self.regions[region][1](addr, length)
        else:
            self.regions[region][addr:addr+len(data)] = data

    def handle_io_read_tlp(self, tlp):
        m = self.match_bar(tlp.address, True)
        if len(m) == 1:
            # logging
            print("[%s] IO read" % (highlight(self.get_desc())))

            assert tlp.length == 1

            # prepare completion TLP
            cpl = TLP()
            cpl.set_completion_data(tlp, self.get_id())

            region = m[0][0]
            addr = m[0][1]
            offset = 0
            start_offset = None
            mask = tlp.first_be

            # perform read
            data = bytearray(4)

            for k in range(4):
                if mask & (1 << k):
                    if start_offset is None:
                        start_offset = offset
                else:
                    if start_offset is not None and offset != start_offset:
                        data[start_offset:offset] = self.read_region(region, addr+start_offset, offset-start_offset)
                    start_offset = None

                offset += 1

            if start_offset is not None and offset != start_offset:
                data[start_offset:offset] = self.read_region(region, addr+start_offset, offset-start_offset)

            cpl.set_data(data)
            cpl.byte_count = 4
            cpl.length = 1

            # logging
            print("[%s] Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
            yield from self.send(cpl)

        else:
            # logging
            print("IO request did not match any BARs")

            # Unsupported request
            cpl = TLP()
            cpl.set_ur_completion(tlp, self.get_id())
            # logging
            print("[%s] UR Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
            yield from self.send(cpl)

    def handle_io_write_tlp(self, tlp):
        m = self.match_bar(tlp.address, True)
        if len(m) == 1:
            # logging
            print("[%s] IO write" % (highlight(self.get_desc())))

            assert tlp.length == 1

            # prepare completion TLP
            cpl = TLP()
            cpl.set_completion(tlp, self.get_id())

            region = m[0][0]
            addr = m[0][1]
            offset = 0
            start_offset = None
            mask = tlp.first_be

            # perform write
            data = tlp.get_data()

            for k in range(4):
                if mask & (1 << k):
                    if start_offset is None:
                        start_offset = offset
                else:
                    if start_offset is not None and offset != start_offset:
                        self.write_region(region, addr+start_offset, data[start_offset:offset])
                    start_offset = None

                offset += 1

            if start_offset is not None and offset != start_offset:
                self.write_region(region, addr+start_offset, data[start_offset:offset])

            cpl.byte_count = 4

            # logging
            print("[%s] Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
            yield from self.send(cpl)

        else:
            # logging
            print("IO request did not match any BARs")

            # Unsupported request
            cpl = TLP()
            cpl.set_ur_completion(tlp, self.get_id())
            # logging
            print("[%s] UR Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
            yield from self.send(cpl)

    def handle_mem_read_tlp(self, tlp):
        m = self.match_bar(tlp.address)
        if len(m) == 1:
            print("[%s] Memory read" % (highlight(self.get_desc())))

            # perform operation
            region = m[0][0]
            addr = m[0][1]

            # check for 4k boundary crossing
            if tlp.length*4 > 0x1000 - (addr & 0xfff):
                print("Request crossed 4k boundary, discarding request")
                return

            # perform read
            data = bytearray(self.read_region(region, addr, tlp.length*4))

            # prepare completion TLP(s)
            m = 0
            n = 0
            addr = tlp.address+tlp.get_first_be_offset()
            dw_length = tlp.length
            byte_length = tlp.get_be_byte_count()

            while m < dw_length:
                cpl = TLP()
                cpl.set_completion_data(tlp, self.get_id())

                cpl_dw_length = dw_length - m
                cpl_byte_length = byte_length - n
                cpl.byte_count = cpl_byte_length
                if cpl_dw_length > 32 << self.max_payload_size:
                    cpl_dw_length = 32 << self.max_payload_size # max payload size
                    cpl_dw_length -= (addr & 0x7c) >> 2 # RCB align

                cpl.lower_address = addr & 0x7f

                cpl.set_data(data[m*4:(m+cpl_dw_length)*4])

                # logging
                print("[%s] Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
                yield from self.send(cpl)

                m += cpl_dw_length;
                n += cpl_dw_length*4 - (addr&3)
                addr += cpl_dw_length*4 - (addr&3)

        else:
            # logging
            print("Memory request did not match any BARs")

            # Unsupported request
            cpl = TLP()
            cpl.set_ur_completion(tlp, self.get_id())
            # logging
            print("[%s] UR Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
            yield from self.send(cpl)

    def handle_mem_write_tlp(self, tlp):
        m = self.match_bar(tlp.address)
        if len(m) == 1:
            # logging
            print("[%s] Memory write" % (highlight(self.get_desc())))

            # perform operation
            region = m[0][0]
            addr = m[0][1]
            offset = 0
            start_offset = None
            mask = tlp.first_be

            # check for 4k boundary crossing
            if tlp.length*4 > 0x1000 - (addr & 0xfff):
                print("Request crossed 4k boundary, discarding request")
                return

            # perform write
            data = tlp.get_data()

            # first dword
            for k in range(4):
                if mask & (1 << k):
                    if start_offset is None:
                        start_offset = offset
                else:
                    if start_offset is not None and offset != start_offset:
                        self.write_region(region, addr+start_offset, data[start_offset:offset])
                    start_offset = None

                offset += 1

            if tlp.length > 2:
                # middle dwords
                if start_offset is None:
                    start_offset = offset
                offset += (tlp.length-2)*4

            if tlp.length > 1:
                # last dword
                mask = tlp.last_be

                for k in range(4):
                    if mask & (1 << k):
                        if start_offset is None:
                            start_offset = offset
                    else:
                        if start_offset is not None and offset != start_offset:
                            self.write_region(region, addr+start_offset, data[start_offset:offset])
                        start_offset = None

                    offset += 1

            if start_offset is not None and offset != start_offset:
                self.write_region(region, addr+start_offset, data[start_offset:offset])

            # memory writes are posted, so don't send a completion

        else:
            # logging
            print("Memory request did not match any BARs")


class Bridge(Function):
    """PCIe bridge function, implements bridge config space and TLP routing"""
    def __init__(self, *args, **kwargs):
        super(Bridge, self).__init__(*args, **kwargs)

        # configuration registers
        self.header_type = 1
        self.bar = [0]*2
        self.bar_mask = [0]*2
        self.pri_bus_num = 0
        self.sec_bus_num = 0
        self.sub_bus_num = 0
        self.sec_lat_timer = 0
        self.io_base = 0x0000
        self.io_limit = 0x0fff
        self.sec_status = 0
        self.mem_base = 0x00000000
        self.mem_limit = 0x000fffff
        self.prefetchable_mem_base = 0x00000000
        self.prefetchable_mem_limit = 0x000fffff
        self.bridge_control = 0

        self.pcie_device_type = 0x6

        self.root = False

        self.upstream_port = Port(self, self.upstream_recv)
        self.upstream_tx_handler = self.upstream_port.send

        self.downstream_port = Port(self, self.downstream_recv)
        self.downstream_tx_handler = self.downstream_port.send

    """
    Bridge (type 1) config space

    31                                                                  0
    +---------------------------------+---------------------------------+
    |            Device ID            |            Vendor ID            |   0   0x00
    +---------------------------------+---------------------------------+
    |             Status              |             Command             |   1   0x04
    +---------------------------------+----------------+----------------+
    |                    Class Code                    |  Revision ID   |   2   0x08
    +----------------+----------------+----------------+----------------+
    |      BIST      |  Header Type   |    Primary     |   Cache Line   |   3   0x0C
    |                |                | Latency Timer  |      Size      |
    +----------------+----------------+----------------+----------------+
    |                      Base Address Register 0                      |   4   0x10
    +-------------------------------------------------------------------+
    |                      Base Address Register 1                      |   5   0x14
    +----------------+----------------+----------------+----------------+
    | Secondary      | Subordinate    | Secondary      | Primary        |   6   0x18
    | Latency Timer  | Bus Number     | Bus Number     | Bus Number     |
    +----------------+----------------+----------------+----------------+
    |        Secondary Status         |    IO Limit    |    IO Base     |   7   0x1C
    +---------------------------------+----------------+----------------+
    |          Memory Limit           |           Memory Base           |   8   0x20
    +---------------------------------+---------------------------------+
    |    Prefetchable Memory Limit    |    Prefetchable Memory Base     |   9   0x24
    +---------------------------------+---------------------------------+
    |                    Prefetchable Base Upper 32                     |  10   0x28
    +-------------------------------------------------------------------+
    |                    Prefetchable Limit Upper 32                    |  11   0x2C
    +---------------------------------+---------------------------------+
    |         IO Lim Upper 16         |        IO Base Lower 16         |  12   0x30
    +---------------------------------+----------------+----------------+
    |                     Reserved                     |    Cap Ptr     |  13   0x34
    +--------------------------------------------------+----------------+
    |                    Expansion ROM Base Address                     |  14   0x38
    +---------------------------------+----------------+----------------+
    |         Bridge Control          |    Int Pin     |    Int Line    |  15   0x3C
    +---------------------------------+----------------+----------------+

    """
    def read_config_register(self, reg):
        if   reg ==  4: return self.bar[0]
        elif reg ==  5: return self.bar[1]
        elif reg ==  6: return (self.sec_lat_timer << 24) | (self.sub_bus_num << 16) | (self.sec_bus_num << 8) | self.pri_bus_num
        elif reg ==  7: return (self.sec_status << 16) | (self.io_limit & 0xf000) | ((self.io_base & 0xf000) >> 8)
        elif reg ==  8: return (self.mem_limit & 0xfff00000) | ((self.mem_base & 0xfff00000) >> 16)
        elif reg ==  9: return (self.prefetchable_mem_limit & 0xfff00000) | ((self.prefetchable_mem_base & 0xfff00000) >> 16)
        elif reg == 10: return self.prefetchable_mem_base >> 32
        elif reg == 11: return self.prefetchable_mem_limit >> 32
        elif reg == 12: return (self.io_limit & 0xffff0000) | ((self.io_base & 0xffff0000) >> 16)
        elif reg == 13: return self.cap_ptr
        elif reg == 14: return self.expansion_rom_addr
        elif reg == 15: return (self.bridge_control << 16) | (self.intr_pin << 8) | self.intr_line
        else:           return super(Bridge, self).read_config_register(reg)

    def write_config_register(self, reg, data, mask):
        if   reg ==  4:
            self.bar[0] = byte_mask_update(self.bar[0], mask, data, self.bar_mask[0])
        if   reg ==  5:
            self.bar[1] = byte_mask_update(self.bar[1], mask, data, self.bar_mask[1])
        elif reg ==  6:
            self.pri_bus_num = byte_mask_update(self.pri_bus_num, mask & 0x1, data)
            self.sec_bus_num = byte_mask_update(self.sec_bus_num, (mask >> 1) & 1, data >> 8)
            self.sub_bus_num = byte_mask_update(self.sub_bus_num, (mask >> 2) & 1, data >> 16)
            self.sec_lat_timer = byte_mask_update(self.sec_lat_timer, (mask >> 3) & 1, data >> 24)
        elif reg ==  7:
            self.io_base = byte_mask_update(self.io_base, (mask & 0x1) << 1, data << 8, 0xf000)
            self.io_limit = byte_mask_update(self.io_limit, (mask & 0x2), data, 0xf000) | 0xfff
            self.sec_status = byte_mask_update(self.sec_status, (mask >> 2) & 1, 0x0000, (data >> 16) & 0xf900)
        elif reg ==  8:
            self.mem_base = byte_mask_update(self.mem_base, (mask & 0x3) << 2, data << 16, 0xfff00000)
            self.mem_limit = byte_mask_update(self.mem_limit, (mask & 0xc), data, 0xfff00000) | 0xfffff
        elif reg ==  9:
            self.prefetchable_mem_base = byte_mask_update(self.prefetchable_mem_base, (mask & 0x3) << 2, data << 16, 0xfff00000)
            self.prefetchable_mem_limit = byte_mask_update(self.prefetchable_mem_limit, (mask & 0xc), data, 0xfff00000) | 0xfffff
        elif reg == 10:
            self.prefetchable_mem_base = byte_mask_update(self.prefetchable_mem_base, mask << 4, data << 32)
        elif reg == 11:
            self.prefetchable_mem_limit = byte_mask_update(self.prefetchable_mem_limit, mask << 4, data << 32)
        elif reg == 12:
            self.io_base = byte_mask_update(self.io_base, (mask & 0x3) << 2, data << 16)
            self.io_limit = byte_mask_update(self.io_limit, (mask & 0xc), data)
        elif reg == 14:
            self.expansion_rom_addr = byte_mask_update(self.expansion_rom_addr, mask, data)
        elif reg == 15:
            self.intr_line = byte_mask_update(self.intr_line, mask & 0x1, data)
            self.intr_pin = byte_mask_update(self.intr_pin, (mask >> 1) & 1, data >> 8)
            self.bridge_control = byte_mask_update(self.min_gnt, (mask >> 2) & 3, data >> 16, 0x0043)
        else:
            super(Bridge, self).write_config_register(reg, data, mask)

    def upstream_send(self, tlp):
        assert tlp.check()
        if self.upstream_tx_handler is None:
            raise Exception("Transmit handler not set")
        yield from self.upstream_tx_handler(tlp)

    def upstream_recv(self, tlp):
        # logging
        if trace_routing:
            print("[%s] Routing downstream TLP: %s" % (highlight(self.get_desc()), repr(tlp)))
        assert tlp.check()
        if tlp.fmt_type == TLP_CFG_READ_0 or tlp.fmt_type == TLP_CFG_WRITE_0:
            yield from self.handle_tlp(tlp)
        elif tlp.fmt_type == TLP_CFG_READ_1 or tlp.fmt_type == TLP_CFG_WRITE_1:
            # config type 1
            if self.sec_bus_num <= tlp.dest_id.bus <= self.sub_bus_num:
                if tlp.dest_id.bus == self.sec_bus_num:
                    # targeted to directly connected device; change to type 0
                    if tlp.fmt_type == TLP_CFG_READ_1:
                        tlp.fmt_type = TLP_CFG_READ_0
                    elif tlp.fmt_type == TLP_CFG_WRITE_1:
                        tlp.fmt_type = TLP_CFG_WRITE_0
                yield from self.route_downstream_tlp(tlp, False)
            else:
                # error
                pass
        elif (tlp.fmt_type == TLP_CPL or tlp.fmt_type == TLP_CPL_DATA or
                tlp.fmt_type == TLP_CPL_LOCKED or tlp.fmt_type == TLP_CPL_LOCKED_DATA):
            # Completions
            if not self.root and tlp.requester_id == self.get_id():
                # for me
                yield from self.handle_tlp(tlp)
            elif self.sec_bus_num <= tlp.requester_id.bus <= self.sub_bus_num:
                yield from self.route_downstream_tlp(tlp, False)
            else:
                # error
                pass
        elif tlp.fmt_type == TLP_MSG_ID or tlp.fmt_type == TLP_MSG_DATA_ID:
            # ID routed message
            if not self.root and tlp.dest_id == self.get_id():
                # for me
                yield from self.handle_tlp(tlp)
            elif self.sec_bus_num <= tlp.dest_id.bus <= self.sub_bus_num:
                yield from self.route_downstream_tlp(tlp, False)
            else:
                # error
                pass
        elif (tlp.fmt_type == TLP_IO_READ or tlp.fmt_type == TLP_IO_WRITE):
            # IO read/write
            if self.match_bar(tlp.address, io=True):
                # for me
                yield from self.handle_tlp(tlp)
            elif self.io_base <= tlp.address <= self.io_limit:
                yield from self.route_downstream_tlp(tlp, False)
            else:
                # error
                pass
        elif (tlp.fmt_type == TLP_MEM_READ or tlp.fmt_type == TLP_MEM_READ_64 or
                tlp.fmt_type == TLP_MEM_WRITE or tlp.fmt_type == TLP_MEM_WRITE_64):
            # Memory read/write
            if self.match_bar(tlp.address):
                # for me
                yield from self.handle_tlp(tlp)
            elif self.mem_base <= tlp.address <= self.mem_limit or self.prefetchable_mem_base <= tlp.address <= self.prefetchable_mem_limit:
                yield from self.route_downstream_tlp(tlp, False)
            else:
                # error
                pass
        elif tlp.fmt_type == TLP_MSG_TO_RC or tlp.fmt_type == TLP_MSG_DATA_TO_RC:
            # Message to root complex
            # error
            pass
        elif tlp.fmt_type == TLP_MSG_BCAST or tlp.fmt_type == TLP_MSG_DATA_BCAST:
            # Message broadcast from root complex
            yield from self.route_downstream_tlp(tlp, False)
        elif tlp.fmt_type == TLP_MSG_LOCAL or tlp.fmt_type == TLP_MSG_DATA_LOCAL:
            # Message local to receiver
            # error
            pass
        elif tlp.fmt_type == TLP_MSG_GATHER or tlp.fmt_type == TLP_MSG_DATA_GATHER:
            # Message gather to root complex
            # error
            pass
        else:
            # logging
            raise Exception("Unknown/invalid packet type")

    def route_downstream_tlp(self, tlp, from_downstream=False):
        yield from self.downstream_send(tlp)

    def downstream_send(self, tlp):
        assert tlp.check()
        if self.downstream_tx_handler is None:
            raise Exception("Transmit handler not set")
        yield from self.downstream_tx_handler(tlp)

    def downstream_recv(self, tlp):
        # logging
        if trace_routing:
            print("[%s] Routing upstream TLP: %s" % (highlight(self.get_desc()), repr(tlp)))
        assert tlp.check()
        if (tlp.fmt_type == TLP_CFG_READ_0 or tlp.fmt_type == TLP_CFG_WRITE_0 or
                tlp.fmt_type == TLP_CFG_READ_1 or tlp.fmt_type == TLP_CFG_WRITE_1):
            # error
            pass
        elif (tlp.fmt_type == TLP_CPL or tlp.fmt_type == TLP_CPL_DATA or
                tlp.fmt_type == TLP_CPL_LOCKED or tlp.fmt_type == TLP_CPL_LOCKED_DATA):
            # Completions
            if not self.root and tlp.requester_id == self.get_id():
                # for me
                yield from self.handle_tlp(tlp)
            elif self.sec_bus_num <= tlp.requester_id.bus <= self.sub_bus_num:
                if self.root and tlp.requester_id.bus == self.pri_bus_num and tlp.requester_id.device == 0:
                    yield from self.upstream_send(tlp)
                else:
                    yield from self.route_downstream_tlp(tlp, True)
            else:
                yield from self.upstream_send(tlp)
        elif tlp.fmt_type == TLP_MSG_ID or tlp.fmt_type == TLP_MSG_DATA_ID:
            # ID routed messages
            if not self.root and tlp.dest_id == self.get_id():
                # for me
                yield from self.handle_tlp(tlp)
            elif self.sec_bus_num <= tlp.dest_id.bus <= self.sub_bus_num:
                if self.root and tlp.dest_id.bus == self.pri_bus_num and tlp.dest_id.device == 0:
                    yield from self.upstream_send(tlp)
                else:
                    yield from self.route_downstream_tlp(tlp, True)
            else:
                yield from self.upstream_send(tlp)
        elif (tlp.fmt_type == TLP_IO_READ or tlp.fmt_type == TLP_IO_WRITE):
            # IO read/write
            if self.match_bar(tlp.address, io=True):
                # for me
                yield from self.handle_tlp(tlp)
            elif self.io_base <= tlp.address <= self.io_limit:
                yield from self.route_downstream_tlp(tlp, True)
            else:
                yield from self.upstream_send(tlp)
        elif (tlp.fmt_type == TLP_MEM_READ or tlp.fmt_type == TLP_MEM_READ_64 or
                tlp.fmt_type == TLP_MEM_WRITE or tlp.fmt_type == TLP_MEM_WRITE_64):
            # Memory read/write
            if self.match_bar(tlp.address):
                # for me
                yield from self.handle_tlp(tlp)
            elif self.mem_base <= tlp.address <= self.mem_limit or self.prefetchable_mem_base <= tlp.address <= self.prefetchable_mem_limit:
                yield from self.route_downstream_tlp(tlp, True)
            else:
                yield from self.upstream_send(tlp)
        elif tlp.fmt_type == TLP_MSG_TO_RC or tlp.fmt_type == TLP_MSG_DATA_TO_RC:
            # Message to root complex
            yield from self.upstream_send(tlp)
        elif tlp.fmt_type == TLP_MSG_BCAST or tlp.fmt_type == TLP_MSG_DATA_BCAST:
            # Message broadcast from root complex
            # error
            pass
        elif tlp.fmt_type == TLP_MSG_LOCAL or tlp.fmt_type == TLP_MSG_DATA_LOCAL:
            # Message local to receiver
            # error
            pass
        elif tlp.fmt_type == TLP_MSG_GATHER or tlp.fmt_type == TLP_MSG_DATA_GATHER:
            # Message gather to root complex
            raise Exception("TODO")
        else:
            raise Exception("Unknown/invalid packet type")

    def send(self, tlp):
        # route local transmissions as if they came in via downstream port
        yield from self.downstream_recv(tlp)


class SwitchUpstreamPort(Bridge):
    def __init__(self, *args, **kwargs):
        super(SwitchUpstreamPort, self).__init__(*args, **kwargs)

        self.pcie_device_type = 0x5

        self.downstream_port = BusPort(self, self.downstream_recv)
        self.downstream_tx_handler = None

        self.desc = "SwitchUpstreamPort"

        self.vendor_id = 0x1234
        self.device_id = 0x0003

    def route_downstream_tlp(self, tlp, from_downstream=False):
        assert tlp.check()

        # route downstream packet
        ok = False
        for p in self.downstream_port.other:
            dev = p.parent
            if tlp.fmt_type == TLP_CFG_READ_0 or tlp.fmt_type == TLP_CFG_WRITE_0:
                # config type 0
                if tlp.dest_id.device == dev.device_num and tlp.dest_id.function == dev.function_num:
                    yield from p.ext_recv(TLP(tlp))
                    return
            elif tlp.fmt_type == TLP_CFG_READ_1 or tlp.fmt_type == TLP_CFG_WRITE_1:
                # config type 1
                if isinstance(dev, Bridge) and dev.sec_bus_num <= tlp.dest_id.bus <= dev.sub_bus_num:
                    yield from p.ext_recv(TLP(tlp))
                    return
            elif (tlp.fmt_type == TLP_CPL or tlp.fmt_type == TLP_CPL_DATA or
                    tlp.fmt_type == TLP_CPL_LOCKED or tlp.fmt_type == TLP_CPL_LOCKED_DATA):
                # Completions
                if tlp.requester_id == dev.get_id():
                    yield from p.ext_recv(TLP(tlp))
                    return
                elif isinstance(dev, Bridge) and dev.sec_bus_num <= tlp.requester_id.bus <= dev.sub_bus_num:
                    yield from p.ext_recv(TLP(tlp))
                    return
            elif tlp.fmt_type == TLP_MSG_ID or tlp.fmt_type == TLP_MSG_DATA_ID:
                # ID routed message
                if tlp.dest_id == dev.get_id():
                    yield from p.ext_recv(TLP(tlp))
                    return
                elif isinstance(dev, Bridge) and dev.sec_bus_num <= tlp.requester_id.bus <= dev.sub_bus_num:
                    yield from p.ext_recv(TLP(tlp))
                    return
            elif (tlp.fmt_type == TLP_IO_READ or tlp.fmt_type == TLP_IO_WRITE):
                # IO read/write
                if dev.match_bar(tlp.address, True):
                    yield from p.ext_recv(TLP(tlp))
                    return
                elif isinstance(dev, Bridge) and dev.io_base <= tlp.address <= dev.io_limit:
                    yield from p.ext_recv(TLP(tlp))
                    return
            elif (tlp.fmt_type == TLP_MEM_READ or tlp.fmt_type == TLP_MEM_READ_64 or
                    tlp.fmt_type == TLP_MEM_WRITE or tlp.fmt_type == TLP_MEM_WRITE_64):
                # Memory read/write
                if dev.match_bar(tlp.address):
                    yield from p.ext_recv(TLP(tlp))
                    return
                elif isinstance(dev, Bridge) and (dev.mem_base <= tlp.address <= dev.mem_limit or dev.prefetchable_mem_base <= tlp.address <= dev.prefetchable_mem_limit):
                    yield from p.ext_recv(TLP(tlp))
                    return
            elif tlp.fmt_type == TLP_MSG_TO_RC or tlp.fmt_type == TLP_MSG_DATA_TO_RC:
                # Message to root complex
                # error
                pass
            elif tlp.fmt_type == TLP_MSG_BCAST or tlp.fmt_type == TLP_MSG_DATA_BCAST:
                # Message broadcast from root complex
                yield from p.ext_recv(TLP(tlp))
                ok = True
            elif tlp.fmt_type == TLP_MSG_LOCAL or tlp.fmt_type == TLP_MSG_DATA_LOCAL:
                # Message local to receiver
                # error
                pass
            elif tlp.fmt_type == TLP_MSG_GATHER or tlp.fmt_type == TLP_MSG_DATA_GATHER:
                # Message gather to root complex
                # error
                pass
            else:
                # logging
                raise Exception("Unknown/invalid packet type")

        if not ok:
            # Unsupported request
            cpl = TLP()
            cpl.set_ur_completion(tlp, (self.bus_num, self.device_num, 0))
            # logging
            print("[%s] UR Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
            if from_downstream:
                yield from self.route_downstream_tlp(cpl, False)
            else:
                yield from self.upstream_send(cpl)


class SwitchDownstreamPort(Bridge):
    def __init__(self, *args, **kwargs):
        super(SwitchDownstreamPort, self).__init__(*args, **kwargs)

        self.pcie_device_type = 0x6

        self.desc = "SwitchDownstreamPort"

        self.vendor_id = 0x1234
        self.device_id = 0x0004

    def connect(self, port):
        self.downstream_port.connect(port)


class HostBridge(SwitchUpstreamPort):
    def __init__(self, *args, **kwargs):
        super(HostBridge, self).__init__(*args, **kwargs)

        self.desc = "HostBridge"

        self.vendor_id = 0x1234
        self.device_id = 0x0001

        self.pri_bus_num = 0
        self.sec_bus_num = 0
        self.sub_bus_num = 255


class RootPort(SwitchDownstreamPort):
    def __init__(self, *args, **kwargs):
        super(RootPort, self).__init__(*args, **kwargs)

        self.pcie_device_type = 0x4

        self.desc = "RootPort"

        self.vendor_id = 0x1234
        self.device_id = 0x0002

    def connect(self, port):
        self.downstream_port.connect(port)


class Device(object):
    """PCIe device, container for multiple functions"""
    def __init__(self, eps=None):
        self.bus_num = 0
        self.device_num = 0

        self.desc = "Device"

        self.default_function = Endpoint

        self.functions = []
        self.upstream_port = Port(self, self.upstream_recv)

        if eps:
            try:
                for ep in eps:
                    self.append_function(ep)
            except:
                self.append_function(eps)

    def get_desc(self):
        return "%02x:%02x %s" % (self.bus_num, self.device_num, self.desc)

    def next_free_function_number(self):
        self.functions.sort(key=lambda x: x.function_num)
        if not self.functions:
            return 0
        for x in range(len(self.functions)):
            if self.functions[x].function_num != x:
                return x
        if len(self.functions) < 8:
            return len(self.functions)
        return None

    def add_function(self, function):
        for f in self.functions:
            if f.function_num == function.function_num:
                raise Exception("Function number already in use")
        function.upstream_tx_handler = self.upstream_send
        self.functions.append(function)
        self.functions.sort(key=lambda x: x.function_num)
        if len(self.functions) > 1:
            for f in self.functions:
                f.header_type |= 0x80
        return function

    def append_function(self, function):
        function.function_num = self.next_free_function_number()
        return self.add_function(function)

    def make_function(self):
        return self.append_function(self.default_function())

    def connect(self, port):
        self.upstream_port.connect(port)

    def upstream_recv(self, tlp):
        # logging
        print("[%s] Got downstream TLP: %s" % (highlight(self.get_desc()), repr(tlp)))
        assert tlp.check()
        if tlp.fmt_type == TLP_CFG_READ_0 or tlp.fmt_type == TLP_CFG_WRITE_0:
            # config type 0

            if tlp.dest_id.device == self.device_num:
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
                        yield from f.upstream_recv(tlp)
                        return

                print("Function not found")
            else:
                print("Bus/device number mismatch")
        elif (tlp.fmt_type == TLP_IO_READ or tlp.fmt_type == TLP_IO_WRITE):
            # IO read/write

            for f in self.functions:
                if f.match_bar(tlp.address, True):
                    yield from f.upstream_recv(tlp)
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
                if f.match_bar(tlp.address):
                    yield from f.upstream_recv(tlp)
                    return

            print("Memory request did not match any BARs")

            if tlp.fmt_type == TLP_MEM_READ or tlp.fmt_type == TLP_MEM_READ_64:
                # Unsupported request
                cpl = TLP()
                cpl.set_ur_completion(tlp, (self.bus_num, self.device_num, 0))
                # logging
                print("[%s] UR Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
                yield from self.upstream_send(cpl)
        else:
            raise Exception("TODO")

    def upstream_send(self, tlp):
        # logging
        print("[%s] Sending upstream TLP: %s" % (highlight(self.get_desc()), repr(tlp)))
        assert tlp.check()
        yield from self.upstream_port.send(tlp)

    def send(self, tlp):
        yield from self.upstream_send(tlp)


class Switch(object):
    """Switch object, container for switch bridges and associated interconnect"""
    def __init__(self, *args, **kwargs):
        super(Switch, self).__init__(*args, **kwargs)
        self.upstream_bridge = SwitchUpstreamPort()

        self.default_switch_port = SwitchDownstreamPort

        self.min_dev = 1
        self.endpoints = []

    def next_free_device_number(self):
        self.endpoints.sort(key=lambda x: (x.device_num, x.function_num))
        d = self.min_dev
        if not self.endpoints:
            return d
        for ep in self.endpoints:
            if ep.device_num > d:
                return d
            d = ep.device_num + 1
        if d < 32:
            return d
        return None

    def append_endpoint(self, ep):
        ep.upstream_tx_handler = self.upstream_bridge.downstream_recv
        self.endpoints.append(ep)
        self.endpoints.sort(key=lambda x: (x.device_num, x.function_num))
        return ep

    def add_endpoint(self, ep):
        ep.bus_num = 0
        ep.device_num = self.next_free_device_number()
        ep.function_num = 0
        return self.append_endpoint(ep)

    def make_port(self):
        port = self.default_switch_port()
        self.upstream_bridge.downstream_port.connect(port.upstream_port)
        port.pri_bus_num = 0
        port.sec_bus_num = 0
        port.sub_bus_num = 0
        return self.add_endpoint(port)

    def connect(self, port):
        self.upstream_bridge.upstream_port.connect(port)


class TreeItem(object):
    def __init__(self):
        self.bus_num = 0
        self.device_num = 0
        self.function_num = 0

        self.vendor_id = 0
        self.device_id = 0

        self.desc = "(Unknown)"

        self.sec_bus_num = 0
        self.sub_bus_num = 0

        self.bar = [None]*6
        self.bar_size = [None]*6

        self.io_base = 0
        self.io_limit = 0
        self.mem_base = 0
        self.mem_limit = 0
        self.prefetchable_mem_base = 0
        self.prefetchable_mem_limit = 0

        self.capabilities = []
        self.ext_capabilities = []

        self.msi_addr = None
        self.msi_data = None

        self.children = []

    def find_dev(self, dev_id):
        if dev_id == self.get_id():
            return self
        for c in self.children:
            res = c.find_dev(dev_id)
            if res is not None:
                return res
        return None

    def get_capability_offset(self, cap_id):
        for c in self.capabilities:
            if c[0] == cap_id:
                return c[1]
        return None

    def to_str(self, prefix=''):
        s = ''

        if self.sub_bus_num > self.sec_bus_num:
            s += '[%02x-%02x]-' % (self.sec_bus_num, self.sub_bus_num)
            prefix += ' '*8
        else:
            s += '[%02x]-' % (self.sec_bus_num)
            prefix += ' '*5

        for i in range(len(self.children)):
            c = self.children[i]

            if i > 0:
                s += prefix

            if len(self.children) == 1:
                s += '-'
            elif len(self.children)-1 == i:
                s += '\\'
            else:
                s += '+'

            s += '-%02x.%x' % (c.device_num, c.function_num)

            if c.children:
                if i < len(self.children)-1:
                    s += '-'+c.to_str(prefix+'|'+' '*6).strip()
                else:
                    s += '-'+c.to_str(prefix+' '*7).strip()

            s += '\n'

        return s

    def get_id(self):
        return PcieId(self.bus_num, self.device_num, self.function_num)

    def __bool__(self):
        return True

    def __getitem__(self, key):
        return self.children[key]

    def __iter__(self):
        return self.children.__iter__()
    
    def __len__(self):
        return len(self.children)


class RootComplex(Switch):
    def __init__(self, *args, **kwargs):
        super(RootComplex, self).__init__(*args, **kwargs)

        self.default_switch_port = RootPort

        self.min_dev = 1

        self.current_tag = 0

        self.downstream_tag_recv_queues = {}

        self.rx_cpl_queues = [[] for k in range(256)]
        self.rx_cpl_sync = [Signal(False) for k in range(256)]

        self.rx_tlp_handler = {}

        self.upstream_bridge = HostBridge()
        self.upstream_bridge.root = True
        self.upstream_bridge.upstream_tx_handler = self.downstream_recv

        self.tree = TreeItem()

        self.io_base = 0x80000000
        self.io_limit = self.io_base
        self.mem_base = 0x80000000
        self.mem_limit = self.mem_base
        self.prefetchable_mem_base = 0x8000000000000000
        self.prefetchable_mem_limit = self.prefetchable_mem_base

        self.upstream_bridge.io_base = self.io_base
        self.upstream_bridge.io_limit = self.io_limit
        self.upstream_bridge.mem_base = self.mem_base
        self.upstream_bridge.mem_limit = self.mem_limit
        self.upstream_bridge.prefetchable_mem_base = self.prefetchable_mem_base
        self.upstream_bridge.prefetchable_mem_limit = self.prefetchable_mem_limit

        self.max_payload_size = 0
        self.max_read_request_size = 2
        self.read_completion_boundary = 128
        self.extended_tag_field_enable = True

        self.region_base = 0
        self.region_limit = self.region_base

        self.io_region_base = 0
        self.io_region_limit = self.io_region_base

        self.regions = []
        self.io_regions = []

        self.msi_addr = None
        self.msi_msg_limit = 0
        self.msi_signals = {}
        self.msi_callbacks = {}

        self.register_rx_tlp_handler(TLP_IO_READ, self.handle_io_read_tlp)
        self.register_rx_tlp_handler(TLP_IO_WRITE, self.handle_io_write_tlp)
        self.register_rx_tlp_handler(TLP_MEM_READ, self.handle_mem_read_tlp)
        self.register_rx_tlp_handler(TLP_MEM_READ_64, self.handle_mem_read_tlp)
        self.register_rx_tlp_handler(TLP_MEM_WRITE, self.handle_mem_write_tlp)
        self.register_rx_tlp_handler(TLP_MEM_WRITE_64, self.handle_mem_write_tlp)

    def get_desc(self):
        #return "%02x:%02x.%x %s" % (self.bus_num, self.device_num, self.function_num, self.desc)
        return "RootComplex"

    def alloc_region(self, size, read=None, write=None):
        addr = 0
        mem = None

        addr = align(self.region_limit, 2**math.ceil(math.log(size, 2))-1)
        self.region_limit = addr+size-1
        if not read and not write:
            mem = mmap.mmap(-1, size)
            self.regions.append((addr, size, mem))
        else:
            self.regions.append((addr, size, read, write))

        return addr, mem

    def alloc_io_region(self, size, read=None, write=None):
        addr = 0
        mem = None

        addr = align(self.io_region_limit, 2**math.ceil(math.log(size, 2))-1)
        self.io_region_limit = addr+size-1
        if not read and not write:
            mem = mmap.mmap(-1, size)
            self.io_regions.append((addr, size, mem))
        else:
            self.io_regions.append((addr, size, read, write))

        return addr, mem

    def find_region(self, addr):
        for region in self.regions:
            if region[0] <= addr < region[0]+region[1]:
                return region
        return None

    def find_io_region(self, addr):
        for region in self.io_regions:
            if region[0] <= addr < region[0]+region[1]:
                return region
        return None

    def read_region(self, addr, length):
        region = self.find_region(addr)
        if not region:
            raise Exception("Invalid address")
        offset = addr - region[0]
        if len(region) == 3:
            return region[2][offset:offset+length]
        elif len(region) == 4:
            if inspect.isgeneratorfunction(region[2]):
                yield from region[2](offset, length)
            else:
                region[2](offset, length)

    def write_region(self, addr, data):
        region = self.find_region(addr)
        if not region:
            raise Exception("Invalid address")
        offset = addr - region[0]
        if len(region) == 3:
            region[2][offset:offset+len(data)] = data
        elif len(region) == 4:
            if inspect.isgeneratorfunction(region[3]):
                yield from region[3](offset, data)
            else:
                region[3](offset, data)

    def read_io_region(self, addr, length):
        region = self.find_io_region(addr)
        if not region:
            raise Exception("Invalid address")
        offset = addr - region[0]
        if len(region) == 3:
            return region[2][offset:offset+length]
        elif len(region) == 4:
            if inspect.isgeneratorfunction(region[2]):
                yield from region[2](offset, data)
            else:
                region[2](offset, data)

    def write_io_region(self, addr, data):
        region = self.find_io_region(addr)
        if not region:
            raise Exception("Invalid address")
        offset = addr - region[0]
        if len(region) == 3:
            region[2][offset:offset+len(data)] = data
        elif len(region) == 4:
            if inspect.isgeneratorfunction(region[3]):
                yield from region[3](offset, data)
            else:
                region[3](offset, data)

    def downstream_send(self, tlp):
        # logging
        print("[%s] Sending TLP: %s" % (highlight(self.get_desc()), repr(tlp)))
        assert tlp.check()
        yield from self.upstream_bridge.upstream_recv(tlp)

    def send(self, tlp):
        yield from self.downstream_send(tlp)

    def downstream_recv(self, tlp):
        # logging
        print("[%s] Got TLP: %s" % (highlight(self.get_desc()), repr(tlp)))
        assert tlp.check()
        yield from self.handle_tlp(tlp)

    def handle_tlp(self, tlp):
        if (tlp.fmt_type == TLP_CPL or tlp.fmt_type == TLP_CPL_DATA or
                tlp.fmt_type == TLP_CPL_LOCKED or tlp.fmt_type == TLP_CPL_LOCKED_DATA):
            self.rx_cpl_queues[tlp.tag].append(tlp)
            self.rx_cpl_sync[tlp.tag].next = not self.rx_cpl_sync[tlp.tag]
        elif tlp.fmt_type in self.rx_tlp_handler:
            yield self.rx_tlp_handler[tlp.fmt_type](tlp)
        else:
            raise Exception("Unhandled TLP")

    def register_rx_tlp_handler(self, fmt_type, func):
        self.rx_tlp_handler[fmt_type] = func

    def recv_cpl(self, tag, timeout=0):
        queue = self.rx_cpl_queues[tag]
        sync = self.rx_cpl_sync[tag]

        if timeout:
            yield sync, delay(timeout)
        else:
            yield sync

        if queue:
            return queue.pop(0)

        return None

    def get_free_tag(self):
        tag_count = 32

        for k in range(tag_count):
            self.current_tag = (self.current_tag + 1) % tag_count
            if not self.rx_cpl_queues[self.current_tag]:
                return self.current_tag

        return None

    def handle_io_read_tlp(self, tlp):
        if self.find_io_region(tlp.address):
            # logging
            print("[%s] IO read" % (highlight(self.get_desc())))

            assert tlp.length == 1

            # prepare completion TLP
            cpl = TLP()
            cpl.set_completion_data(tlp, PcieId(0, 0, 0))

            addr = tlp.address
            offset = 0
            start_offset = None
            mask = tlp.first_be

            # perform read
            data = bytearray(4)

            for k in range(4):
                if mask & (1 << k):
                    if start_offset is None:
                        start_offset = offset
                else:
                    if start_offset is not None and offset != start_offset:
                        data[start_offset:offset] = yield from self.read_io_region(addr+start_offset, offset-start_offset)
                    start_offset = None

                offset += 1

            if start_offset is not None and offset != start_offset:
                data[start_offset:offset] = yield from self.read_io_region(addr+start_offset, offset-start_offset)

            cpl.set_data(data)
            cpl.byte_count = 4
            cpl.length = 1

            # logging
            print("[%s] Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
            yield from self.send(cpl)

        else:
            # logging
            print("IO request did not match any regions")

            # Unsupported request
            cpl = TLP()
            cpl.set_ur_completion(tlp, PcieId(0, 0, 0))
            # logging
            print("[%s] UR Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
            yield from self.send(cpl)

    def handle_io_write_tlp(self, tlp):
        if self.find_io_region(tlp.address):
            # logging
            print("[%s] IO write" % (highlight(self.get_desc())))

            assert tlp.length == 1

            # prepare completion TLP
            cpl = TLP()
            cpl.set_completion(tlp, PcieId(0, 0, 0))

            addr = tlp.address
            offset = 0
            start_offset = None
            mask = tlp.first_be

            # perform write
            data = tlp.get_data()

            for k in range(4):
                if mask & (1 << k):
                    if start_offset is None:
                        start_offset = offset
                else:
                    if start_offset is not None and offset != start_offset:
                        yield from self.write_io_region(addr+start_offset, data[start_offset:offset])
                    start_offset = None

                offset += 1

            if start_offset is not None and offset != start_offset:
                yield from self.write_io_region(addr+start_offset, data[start_offset:offset])

            cpl.byte_count = 4

            # logging
            print("[%s] Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
            yield from self.send(cpl)

        else:
            # logging
            print("IO request did not match any regions")

            # Unsupported request
            cpl = TLP()
            cpl.set_ur_completion(tlp, PcieId(0, 0, 0))
            # logging
            print("[%s] UR Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
            yield from self.send(cpl)

    def handle_mem_read_tlp(self, tlp):
        if self.find_region(tlp.address):
            # logging
            print("[%s] Memory read" % (highlight(self.get_desc())))

            # perform operation
            addr = tlp.address
            offset = 0

            # check for 4k boundary crossing
            if tlp.length*4 > 0x1000 - (addr & 0xfff):
                print("Request crossed 4k boundary, discarding request")
                return

            # perform read
            data = yield from self.read_region(addr, tlp.length*4)

            # prepare completion TLP(s)
            m = 0
            n = 0
            addr = tlp.address+tlp.get_first_be_offset()
            dw_length = tlp.length
            byte_length = tlp.get_be_byte_count()

            while m < dw_length:
                cpl = TLP()
                cpl.set_completion_data(tlp, PcieId(0, 0, 0))

                cpl_dw_length = dw_length - m
                cpl_byte_length = byte_length - n
                cpl.byte_count = cpl_byte_length
                if cpl_dw_length > 32 << self.max_payload_size:
                    cpl_dw_length = 32 << self.max_payload_size # max payload size
                    cpl_dw_length -= (addr & 0x7c) >> 2 # RCB align

                cpl.lower_address = addr & 0x7f

                cpl.set_data(data[m*4:(m+cpl_dw_length)*4])

                # logging
                print("[%s] Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
                yield from self.send(cpl)

                m += cpl_dw_length;
                n += cpl_dw_length*4 - (addr&3)
                addr += cpl_dw_length*4 - (addr&3)

        else:
            # logging
            print("Memory request did not match any regions")

            # Unsupported request
            cpl = TLP()
            cpl.set_ur_completion(tlp, PcieId(0, 0, 0))
            # logging
            print("[%s] UR Completion: %s" % (highlight(self.get_desc()), repr(cpl)))
            yield from self.send(cpl)

    def handle_mem_write_tlp(self, tlp):
        if self.find_region(tlp.address):
            # logging
            print("[%s] Memory write" % (highlight(self.get_desc())))

            # perform operation
            addr = tlp.address
            offset = 0
            start_offset = None
            mask = tlp.first_be

            # check for 4k boundary crossing
            if tlp.length*4 > 0x1000 - (addr & 0xfff):
                print("Request crossed 4k boundary, discarding request")
                return

            # perform write
            data = tlp.get_data()

            # first dword
            for k in range(4):
                if mask & (1 << k):
                    if start_offset is None:
                        start_offset = offset
                else:
                    if start_offset is not None and offset != start_offset:
                        yield from self.write_region(addr+start_offset, data[start_offset:offset])
                    start_offset = None

                offset += 1

            if tlp.length > 2:
                # middle dwords
                if start_offset is None:
                    start_offset = offset
                offset += (tlp.length-2)*4

            if tlp.length > 1:
                # last dword
                mask = tlp.last_be

                for k in range(4):
                    if mask & (1 << k):
                        if start_offset is None:
                            start_offset = offset
                    else:
                        if start_offset is not None and offset != start_offset:
                            yield from self.write_region(addr+start_offset, data[start_offset:offset])
                        start_offset = None

                    offset += 1

            if start_offset is not None and offset != start_offset:
                yield from self.write_region(addr+start_offset, data[start_offset:offset])

            # memory writes are posted, so don't send a completion

        else:
            # logging
            print("Memory request did not match any regions")

    def config_read(self, dev, addr, length, timeout=0):
        n = 0
        data = b''

        while n < length:
            tlp = TLP()
            tlp.fmt_type = TLP_CFG_READ_1
            tlp.requester_id = PcieId(0, 0, 0)
            tlp.tag = self.get_free_tag()
            tlp.dest_id = dev

            first_pad = addr % 4
            byte_length = min(length-n, 4-first_pad)
            tlp.set_be(addr, byte_length)

            tlp.register_number = addr >> 2

            yield from self.send(tlp)
            cpl = yield from self.recv_cpl(tlp.tag, timeout)

            if not cpl or cpl.status != CPL_STATUS_SC:
                d = b'\xff\xff\xff\xff'
            else:
                assert cpl.length == 1
                d = struct.pack('<L', cpl.data[0])

            data += d[first_pad:]

            n += byte_length
            addr += byte_length

        return data[:length]

    def config_read_words(self, dev, addr, count, ws=2, timeout=0):
        assert ws in (1, 2, 4, 8)
        data = yield from self.config_read(dev, addr, count*ws, timeout)
        words = []
        for k in range(count):
            words.append(int.from_bytes(data[ws*k:ws*(k+1)], 'little'))
        return words

    def config_read_dwords(self, dev, addr, count, timeout=0):
        data = yield from self.config_read_words(dev, addr, count, 4, timeout)
        return data

    def config_read_qwords(self, dev, addr, count, timeout=0):
        data = yield from self.config_read_words(dev, addr, count, 8, timeout)
        return data

    def config_read_byte(self, dev, addr, timeout=0):
        data = yield from self.config_read(dev, addr, 1, timeout)
        return data[0]

    def config_read_word(self, dev, addr, timeout=0):
        data = yield from self.config_read_words(dev, addr, 1, timeout=timeout)
        return data[0]

    def config_read_dword(self, dev, addr, timeout=0):
        data = yield from self.config_read_dwords(dev, addr, 1, timeout=timeout)
        return data[0]

    def config_read_qword(self, dev, addr, timeout=0):
        data = yield from self.config_read_qwords(dev, addr, 1, timeout=timeout)
        return data[0]

    def config_write(self, dev, addr, data, timeout=0):
        n = 0

        while n < len(data):
            tlp = TLP()
            tlp.fmt_type = TLP_CFG_WRITE_1
            tlp.requester_id = PcieId(0, 0, 0)
            tlp.tag = self.get_free_tag()
            tlp.dest_id = dev

            first_pad = addr % 4
            byte_length = min(len(data)-n, 4-first_pad)
            tlp.set_be_data(addr, data[n:n+byte_length])

            tlp.register_number = addr >> 2

            yield from self.send(tlp)
            cpl = yield from self.recv_cpl(tlp.tag, timeout)

            n += byte_length
            addr += byte_length

    def config_write_words(self, dev, addr, data, ws=2, timeout=0):
        assert ws in (1, 2, 4, 8)
        words = data
        data = b''
        for w in words:
            data += w.to_bytes(ws, 'little')
        yield from self.config_write(dev, addr, data, timeout)

    def config_write_dwords(self, dev, addr, data, timeout=0):
        yield from self.config_write_words(dev, addr, data, 4, timeout)

    def config_write_qwords(self, dev, addr, data, timeout=0):
        yield from self.config_write_words(dev, addr, data, 8, timeout)

    def config_write_byte(self, dev, addr, data, timeout=0):
        yield from self.config_write(dev, addr, [data], timeout)

    def config_write_word(self, dev, addr, data, timeout=0):
        yield from self.config_write_words(dev, addr, [data], timeout=timeout)

    def config_write_dword(self, dev, addr, data, timeout=0):
        yield from self.config_write_dwords(dev, addr, [data], timeout=timeout)

    def config_write_qword(self, dev, addr, data, timeout=0):
        yield from self.config_write_qwords(dev, addr, [data], timeout=timeout)

    def capability_read(self, dev, cap_id, addr, length, timeout=0):
        ti = self.tree.find_dev(dev)

        if not ti:
            raise Exception("Device not found")

        offset = ti.get_capability_offset(cap_id)

        if not offset:
            raise Exception("Capability not found")

        val = yield from self.config_read(dev, addr+offset, length, timeout)
        return val

    def capability_read_words(self, dev, cap_id, addr, count, ws=2, timeout=0):
        assert ws in (1, 2, 4, 8)
        data = yield from self.capability_read(dev, cap_id, addr, count*ws, timeout)
        words = []
        for k in range(count):
            words.append(int.from_bytes(data[ws*k:ws*(k+1)], 'little'))
        return words

    def capability_read_dwords(self, dev, cap_id, addr, count, timeout=0):
        data = yield from self.capability_read_words(dev, cap_id, addr, count, 4, timeout)
        return data

    def capability_read_qwords(self, dev, cap_id, addr, count, timeout=0):
        data = yield from self.capability_read_words(dev, cap_id, addr, count, 8, timeout)
        return data

    def capability_read_byte(self, dev, cap_id, addr, timeout=0):
        data = yield from self.capability_read(dev, cap_id, addr, 1, timeout)
        return data[0]

    def capability_read_word(self, dev, cap_id, addr, timeout=0):
        data = yield from self.capability_read_words(dev, cap_id, addr, 1, timeout=timeout)
        return data[0]

    def capability_read_dword(self, dev, cap_id, addr, timeout=0):
        data = yield from self.capability_read_dwords(dev, cap_id, addr, 1, timeout=timeout)
        return data[0]

    def capability_read_qword(self, dev, cap_id, addr, timeout=0):
        data = yield from self.capability_read_qwords(dev, cap_id, addr, 1, timeout=timeout)
        return data[0]

    def capability_write(self, dev, cap_id, addr, data, timeout=0):
        ti = self.tree.find_dev(dev)

        if not ti:
            raise Exception("Device not found")

        offset = ti.get_capability_offset(cap_id)

        if not offset:
            raise Exception("Capability not found")

        yield from self.config_write(dev, addr+offset, data, timeout)

    def capability_write_words(self, dev, cap_id, addr, data, ws=2, timeout=0):
        assert ws in (1, 2, 4, 8)
        words = data
        data = b''
        for w in words:
            data += w.to_bytes(ws, 'little')
        yield from self.capability_write(dev, cap_id, addr, data, timeout)

    def capability_write_dwords(self, dev, cap_id, addr, data, timeout=0):
        yield from self.capability_write_words(dev, cap_id, addr, data, 4, timeout)

    def capability_write_qwords(self, dev, cap_id, addr, data, timeout=0):
        yield from self.capability_write_words(dev, cap_id, addr, data, 8, timeout)

    def capability_write_byte(self, dev, cap_id, addr, data, timeout=0):
        yield from self.capability_write(dev, cap_id, addr, [data], timeout)

    def capability_write_word(self, dev, cap_id, addr, data, timeout=0):
        yield from self.capability_write_words(dev, cap_id, addr, [data], timeout=timeout)

    def capability_write_dword(self, dev, cap_id, addr, data, timeout=0):
        yield from self.capability_write_dwords(dev, cap_id, addr, [data], timeout=timeout)

    def capability_write_qword(self, dev, cap_id, addr, data, timeout=0):
        yield from self.capability_write_qwords(dev, cap_id, addr, [data], timeout=timeout)

    def io_read(self, addr, length, timeout=0):
        n = 0
        data = b''

        if self.find_region(addr):
            val = yield from self.read_io_region(addr, length)
            return val

        while n < length:
            tlp = TLP()
            tlp.fmt_type = TLP_IO_READ
            tlp.requester_id = PcieId(0, 0, 0)
            tlp.tag = self.get_free_tag()

            first_pad = addr % 4
            byte_length = min(length-n, 4-first_pad)
            tlp.set_be(addr, byte_length)

            yield from self.send(tlp)
            cpl = yield from self.recv_cpl(tlp.tag, timeout)

            if not cpl:
                raise Exception("Timeout")
            if cpl.status != CPL_STATUS_SC:
                raise Exception("Unsuccessful completion")
            else:
                assert cpl.length == 1
                d = struct.pack('<L', cpl.data[0])

            data += d[first_pad:]

            n += byte_length
            addr += byte_length

        return data[:length]

    def io_read_words(self, addr, count, ws=2, timeout=0, attr=0, tc=0):
        assert ws in (1, 2, 4, 8)
        data = yield from self.io_read(addr, count*ws, timeout, attr, tc)
        words = []
        for k in range(count):
            words.append(int.from_bytes(data[ws*k:ws*(k+1)], 'little'))
        return words

    def io_read_dwords(self, addr, count, timeout=0, attr=0, tc=0):
        data = yield from self.io_read_words(addr, count, 4, timeout, attr, tc)
        return data

    def io_read_qwords(self, addr, count, timeout=0, attr=0, tc=0):
        data = yield from self.io_read_words(addr, count, 8, timeout, attr, tc)
        return data

    def io_read_byte(self, addr, timeout=0, attr=0, tc=0):
        data = yield from self.io_read(addr, 1, timeout, attr, tc)
        return data[0]

    def io_read_word(self, addr, timeout=0, attr=0, tc=0):
        data = yield from self.io_read_words(addr, 1, timeout=timeout, attr=attr, tc=tc)
        return data[0]

    def io_read_dword(self, addr, timeout=0, attr=0, tc=0):
        data = yield from self.io_read_dwords(addr, 1, timeout=timeout, attr=attr, tc=tc)
        return data[0]

    def io_read_qword(self, addr, timeout=0, attr=0, tc=0):
        data = yield from self.io_read_qwords(addr, 1, timeout=timeout, attr=attr, tc=tc)
        return data[0]

    def io_write(self, addr, data, timeout=0):
        n = 0

        if self.find_region(addr):
            yield from self.write_io_region(addr, data)
            return

        while n < len(data):
            tlp = TLP()
            tlp.fmt_type = TLP_IO_WRITE
            tlp.requester_id = PcieId(0, 0, 0)
            tlp.tag = self.get_free_tag()

            first_pad = addr % 4
            byte_length = min(len(data)-n, 4-first_pad)
            tlp.set_be_data(addr, data[n:n+byte_length])

            yield from self.send(tlp)
            cpl = yield from self.recv_cpl(tlp.tag, timeout)

            if not cpl:
                raise Exception("Timeout")
            if cpl.status != CPL_STATUS_SC:
                raise Exception("Unsuccessful completion")

            n += byte_length
            addr += byte_length

    def io_write_words(self, addr, data, ws=2, timeout=0, attr=0, tc=0):
        assert ws in (1, 2, 4, 8)
        words = data
        data = b''
        for w in words:
            data += w.to_bytes(ws, 'little')
        yield from self.io_write(addr, data, timeout, attr, tc)

    def io_write_dwords(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.io_write_words(addr, data, 4, timeout, attr, tc)

    def io_write_qwords(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.io_write_words(addr, data, 8, timeout, attr, tc)

    def io_write_byte(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.io_write(addr, [data], timeout, attr, tc)

    def io_write_word(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.io_write_words(addr, [data], timeout=timeout, attr=attr, tc=tc)

    def io_write_dword(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.io_write_dwords(addr, [data], timeout=timeout, attr=attr, tc=tc)

    def io_write_qword(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.io_write_qwords(addr, [data], timeout=timeout, attr=attr, tc=tc)

    def mem_read(self, addr, length, timeout=0, attr=0, tc=0):
        n = 0
        data = b''

        if self.find_region(addr):
            val = yield from self.read_region(addr, length)
            return val

        while n < length:
            tlp = TLP()
            if addr > 0xffffffff:
                tlp.fmt_type = TLP_MEM_READ_64
            else:
                tlp.fmt_type = TLP_MEM_READ
            tlp.requester_id = PcieId(0, 0, 0)
            tlp.tag = self.get_free_tag()
            tlp.attr = attr
            tlp.tc = tc

            first_pad = addr % 4
            byte_length = length-n
            byte_length = min(byte_length, (128 << self.max_read_request_size)-first_pad) # max read request size
            byte_length = min(byte_length, 0x1000 - (addr & 0xfff)) # 4k align
            tlp.set_be(addr, byte_length)

            yield from self.send(tlp)

            m = 0

            while m < byte_length:
                cpl = yield from self.recv_cpl(tlp.tag, timeout)

                if not cpl:
                    raise Exception("Timeout")
                if cpl.status != CPL_STATUS_SC:
                    raise Exception("Unsuccessful completion")
                else:
                    assert cpl.byte_count+3+(cpl.lower_address&3) >= cpl.length*4
                    assert cpl.byte_count == byte_length - m

                    d = bytearray()

                    for k in range(cpl.length):
                        d.extend(struct.pack('<L', cpl.data[k]))

                    offset = cpl.lower_address&3
                    data += d[offset:offset+cpl.byte_count]

                m += len(d)-offset

            n += byte_length
            addr += byte_length

        return data

    def mem_read_words(self, addr, count, ws=2, timeout=0, attr=0, tc=0):
        assert ws in (1, 2, 4, 8)
        data = yield from self.mem_read(addr, count*ws, timeout, attr, tc)
        words = []
        for k in range(count):
            words.append(int.from_bytes(data[ws*k:ws*(k+1)], 'little'))
        return words

    def mem_read_dwords(self, addr, count, timeout=0, attr=0, tc=0):
        data = yield from self.mem_read_words(addr, count, 4, timeout, attr, tc)
        return data

    def mem_read_qwords(self, addr, count, timeout=0, attr=0, tc=0):
        data = yield from self.mem_read_words(addr, count, 8, timeout, attr, tc)
        return data

    def mem_read_byte(self, addr, timeout=0, attr=0, tc=0):
        data = yield from self.mem_read(addr, 1, timeout, attr, tc)
        return data[0]

    def mem_read_word(self, addr, timeout=0, attr=0, tc=0):
        data = yield from self.mem_read_words(addr, 1, timeout=timeout, attr=attr, tc=tc)
        return data[0]

    def mem_read_dword(self, addr, timeout=0, attr=0, tc=0):
        data = yield from self.mem_read_dwords(addr, 1, timeout=timeout, attr=attr, tc=tc)
        return data[0]

    def mem_read_qword(self, addr, timeout=0, attr=0, tc=0):
        data = yield from self.mem_read_qwords(addr, 1, timeout=timeout, attr=attr, tc=tc)
        return data[0]

    def mem_write(self, addr, data, timeout=0, attr=0, tc=0):
        n = 0

        if self.find_region(addr):
            yield from self.write_region(addr, data)
            return

        while n < len(data):
            tlp = TLP()
            if addr > 0xffffffff:
                tlp.fmt_type = TLP_MEM_WRITE_64
            else:
                tlp.fmt_type = TLP_MEM_WRITE
            tlp.requester_id = PcieId(0, 0, 0)
            tlp.attr = attr
            tlp.tc = tc

            first_pad = addr % 4
            byte_length = len(data)-n
            byte_length = min(byte_length, (128 << self.max_payload_size)-first_pad) # max payload size
            byte_length = min(byte_length, 0x1000 - (addr & 0xfff)) # 4k align
            tlp.set_be_data(addr, data[n:n+byte_length])

            yield from self.send(tlp)

            n += byte_length
            addr += byte_length

    def mem_write_words(self, addr, data, ws=2, timeout=0, attr=0, tc=0):
        assert ws in (1, 2, 4, 8)
        words = data
        data = b''
        for w in words:
            data += w.to_bytes(ws, 'little')
        yield from self.mem_write(addr, data, timeout, attr, tc)

    def mem_write_dwords(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.mem_write_words(addr, data, 4, timeout, attr, tc)

    def mem_write_qwords(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.mem_write_words(addr, data, 8, timeout, attr, tc)

    def mem_write_byte(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.mem_write(addr, [data], timeout, attr, tc)

    def mem_write_word(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.mem_write_words(addr, [data], timeout=timeout, attr=attr, tc=tc)

    def mem_write_dword(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.mem_write_dwords(addr, [data], timeout=timeout, attr=attr, tc=tc)

    def mem_write_qword(self, addr, data, timeout=0, attr=0, tc=0):
        yield from self.mem_write_qwords(addr, [data], timeout=timeout, attr=attr, tc=tc)

    def msi_region_read(self, addr, length):
        return b'\x00'*length

    def msi_region_write(self, addr, data):
        assert addr == 0
        assert len(data) == 4
        number = struct.unpack('<L', data)[0]
        print("MSI interrupt: 0x%08x, 0x%04x" % (addr, number))
        assert number in self.msi_signals
        for sig in self.msi_signals[number]:
            sig.next = not sig
        for cb in self.msi_callbacks[number]:
            if inspect.isgeneratorfunction(cb):
                yield cb(), None
            else:
                cb()

    def configure_msi(self, dev):
        if self.msi_addr is None:
            self.msi_addr, _ = self.alloc_region(4, self.msi_region_read, self.msi_region_write)
        if not self.tree:
            # device tree missing
            return False
        ti = self.tree.find_dev(dev)
        if not ti:
            # device not found
            return False
        if ti.get_capability_offset(MSI_CAP_ID) is None:
            # does not support MSI
            return False
        if ti.msi_addr is not None and ti.msi_data is not None:
            # already configured
            return True

        msg_ctrl = yield from self.capability_read_dword(dev, MSI_CAP_ID, 0)

        msi_64bit = msg_ctrl >> 23 & 1
        msi_mmcap = msg_ctrl >> 17 & 7

        # message address
        yield from self.capability_write_dword(dev, MSI_CAP_ID, 4, self.msi_addr & 0xfffffffc)

        if msi_64bit:
            # 64 bit message address
            # message upper address
            yield from self.capability_write_dword(dev, MSI_CAP_ID, 8, (self.msi_addr >> 32) & 0xffffffff)
            # message data
            yield from self.capability_write_dword(dev, MSI_CAP_ID, 12, self.msi_msg_limit)

        else:
            # 32 bit message address
            # message data
            yield from self.capability_write_dword(dev, MSI_CAP_ID, 8, self.msi_msg_limit)

        # enable and set enabled messages
        yield from self.capability_write_dword(dev, MSI_CAP_ID, 0, (msg_ctrl & ~(7 << 20)) | 1 << 16 | msi_mmcap << 20)

        ti.msi_addr = self.msi_addr
        ti.msi_data = self.msi_msg_limit

        for k in range(32):
            self.msi_signals[self.msi_msg_limit] = [Signal(bool(0))]
            self.msi_callbacks[self.msi_msg_limit] = []
            self.msi_msg_limit += 1

        return True

    def msi_get_signal(self, dev, number=0):
        if not self.tree:
            return None
        ti = self.tree.find_dev(dev)
        if not ti:
            return None
        if ti.msi_data is None:
            return None
        if ti.msi_data+number not in self.msi_signals:
            return None
        return self.msi_signals[ti.msi_data+number][0]

    def msi_register_signal(self, dev, sig, number=0):
        if not self.tree:
            return
        ti = self.tree.find_dev(dev)
        if not ti:
            return
        if ti.msi_data is None:
            return
        if ti.msi_data+number not in self.msi_signals:
            return
        self.msi_signals[ti.msi_data+number].append(sig)

    def msi_register_callback(self, dev, callback, number=0):
        if not self.tree:
            return
        ti = self.tree.find_dev(dev)
        if not ti:
            return
        if ti.msi_data is None:
            return
        if ti.msi_data+number not in self.msi_callbacks:
            return
        self.msi_callbacks[ti.msi_data+number].append(callback)

    def enumerate_segment(self, tree, bus, timeout=1000, enable_bus_mastering=False, configure_msi=False):
        sec_bus = bus+1
        sub_bus = bus

        tree.sec_bus_num = bus

        # align limits against bridge registers
        self.io_limit = align(self.io_limit, 0xfff)
        self.mem_limit = align(self.mem_limit, 0xfffff)
        self.prefetchable_mem_limit = align(self.prefetchable_mem_limit, 0xfffff)

        tree.io_base = self.io_limit
        tree.io_limit = self.io_limit
        tree.mem_base = self.mem_limit
        tree.mem_limit = self.mem_limit
        tree.prefetchable_mem_base = self.prefetchable_mem_limit
        tree.prefetchable_mem_limit = self.prefetchable_mem_limit

        # logging
        print("[%s] Enumerating bus %d" % (highlight(self.get_desc()), bus))

        for d in range(32):
            if bus == 0 and d == 0:
                continue

            # read vendor ID and device ID
            val = yield from self.config_read_dword(PcieId(bus, d, 0), 0x000, timeout)

            if val is None or val == 0xffffffff:
                continue

            # valid vendor ID
            # logging
            print("[%s] Found device at %02x:%02x.%x" % (highlight(self.get_desc()), bus, d, 0))

            fc = 1

            # read type
            val = yield from self.config_read_byte(PcieId(bus, d, 0), 0x00e, timeout)

            if val & 0x80:
                # multifunction device
                fc = 8

            for f in range(fc):
                # read vendor ID and device ID
                val = yield from self.config_read(PcieId(bus, d, f), 0x000, 4, timeout)

                if val is None or val == b'\xff\xff\xff\xff':
                    continue

                ti = TreeItem()
                tree.children.append(ti)
                ti.bus_num = bus
                ti.device_num = d
                ti.function_num = f
                ti.vendor_id, ti.device_id = struct.unpack('<HH', val)

                # logging
                print("[%s] Found function at %02x:%02x.%x" % (highlight(self.get_desc()), bus, d, f))

                # read type
                val = yield from self.config_read_byte(PcieId(bus, d, f), 0x00e, timeout)

                bridge = val & 0x7f == 0x01

                bar_cnt = 6

                if bridge:
                    # found a bridge
                    # logging
                    print("[%s] Found bridge at %02x:%02x.%x" % (highlight(self.get_desc()), bus, d, f))

                    bar_cnt = 2

                # configure base address registers
                bar = 0
                while bar < bar_cnt:
                    # read BAR
                    yield from self.config_write_dword(PcieId(bus, d, f), 0x010+bar*4, 0xffffffff)
                    val = yield from self.config_read_dword(PcieId(bus, d, f), 0x010+bar*4)

                    if val == 0:
                        # unimplemented BAR
                        bar += 1
                        continue
                    
                    # logging
                    print("[%s] Configure %02x:%02x.%x BAR%d" % (highlight(self.get_desc()), bus, d, f, bar))

                    if val & 1:
                        # IO BAR
                        mask = (~val & 0xffffffff) | 3
                        size = mask + 1
                        # logging
                        print("[%s] %02x:%02x.%x IO BAR%d raw: %08x, mask: %08x, size: %d" % (highlight(self.get_desc()), bus, d, f, bar, val, mask, size))

                        # align
                        self.io_limit = align(self.io_limit, mask)

                        val = val & 3 | self.io_limit

                        ti.bar[bar] = val
                        ti.bar_size[bar] = size

                        # logging
                        print("[%s] %02x:%02x.%x IO BAR%d Allocation: %08x, size: %d" % (highlight(self.get_desc()), bus, d, f, bar, val, size))

                        self.io_limit += size

                        # write BAR
                        yield from self.config_write_dword(PcieId(bus, d, f), 0x010+bar*4, val)

                        bar += 1
                    else:
                        # Memory BAR

                        if val & 4:
                            # 64 bit BAR
                            if bar >= bar_cnt-1:
                                raise Exception("Invalid BAR configuration")

                            # read adjacent BAR
                            yield from self.config_write_dword(PcieId(bus, d, f), 0x010+(bar+1)*4, 0xffffffff)
                            val2 = yield from self.config_read_dword(PcieId(bus, d, f), 0x010+(bar+1)*4)
                            val |= val2 << 32
                            mask = (~val & 0xffffffffffffffff) | 15
                            size = mask + 1
                            # logging
                            print("[%s] %02x:%02x.%x (64-bit) Mem BAR%d raw: %016x, mask: %016x, size: %d" % (highlight(self.get_desc()), bus, d, f, bar, val, mask, size))

                            if val & 8:
                                # prefetchable
                                # align and allocate
                                self.prefetchable_mem_limit = align(self.prefetchable_mem_limit, mask)
                                val = val & 15 | self.prefetchable_mem_limit
                                self.prefetchable_mem_limit += size

                            else:
                                # not-prefetchable
                                # logging
                                print("[%s] %02x:%02x.%x (64-bit) Mem BAR%d marked non-prefetchable, allocating from 32-bit non-prefetchable address space" % (highlight(self.get_desc()), bus, d, f, bar))
                                # align and allocate
                                self.mem_limit = align(self.mem_limit, mask)
                                val = val & 15 | self.mem_limit
                                self.mem_limit += size

                            ti.bar[bar] = val
                            ti.bar_size[bar] = size

                            # logging
                            print("[%s] %02x:%02x.%x (64-bit) Mem BAR%d Allocation: %016x, size: %d" % (highlight(self.get_desc()), bus, d, f, bar, val, size))

                            # write BAR
                            yield from self.config_write_dword(PcieId(bus, d, f), 0x010+bar*4, val & 0xffffffff)
                            yield from self.config_write_dword(PcieId(bus, d, f), 0x010+(bar+1)*4, (val >> 32) & 0xffffffff)

                            bar += 2
                        else:
                            # 32 bit BAR
                            mask = (~val & 0xffffffff) | 15
                            size = mask + 1
                            # logging
                            print("[%s] %02x:%02x.%x (32-bit) Mem BAR%d raw: %08x, mask: %08x, size: %d" % (highlight(self.get_desc()), bus, d, f, bar, val, mask, size))

                            if val & 8:
                                # prefetchable
                                # logging
                                print("[%s] %02x:%02x.%x (32-bit) Mem BAR%d marked prefetchable, but allocating as non-prefetchable" % (highlight(self.get_desc()), bus, d, f, bar))

                            # align and allocate
                            self.mem_limit = align(self.mem_limit, mask)
                            val = val & 15 | self.mem_limit
                            self.mem_limit += size

                            ti.bar[bar] = val
                            ti.bar_size[bar] = size

                            # logging
                            print("[%s] %02x:%02x.%x (32-bit) Mem BAR%d Allocation: %08x, size: %d" % (highlight(self.get_desc()), bus, d, f, bar, val, size))

                            # write BAR
                            yield from self.config_write_dword(PcieId(bus, d, f), 0x010+bar*4, val)

                            bar += 1

                # logging
                print("[%s] Walk capabilities of %02x:%02x.%x" % (highlight(self.get_desc()), bus, d, f))

                # walk capabilities
                ptr = yield from self.config_read_byte(PcieId(bus, d, f), 0x34)
                ptr = ptr & 0xfc

                while ptr > 0:
                    val = yield from self.config_read(PcieId(bus, d, f), ptr, 2)
                    # logging
                    print("[%s] Found capability 0x%02x at offset 0x%02x, next ptr 0x%02x" % (highlight(self.get_desc()), val[0], ptr, val[1] & 0xfc))
                    ti.capabilities.append((val[0], ptr))
                    ptr = val[1] & 0xfc

                # walk extended capabilities
                # TODO

                # set max payload size, max read request size, and extended tag enable
                dev_cap = yield from self.capability_read_dword(PcieId(bus, d, f), PCIE_CAP_ID, 4)
                dev_ctrl_sta = yield from self.capability_read_dword(PcieId(bus, d, f), PCIE_CAP_ID, 8)

                max_payload = min(0x5, min(self.max_payload_size, dev_cap & 7))
                ext_tag = bool(self.extended_tag_field_enable and (dev_cap & (1 << 5)))
                max_read_req = min(0x5, self.max_read_request_size)

                new_dev_ctrl = dev_ctrl_sta & 0x00008e1f | (max_payload << 5) | (ext_tag << 8) | (max_read_req << 12)

                yield from self.capability_write_dword(PcieId(bus, d, f), PCIE_CAP_ID, 8, new_dev_ctrl)

                if enable_bus_mastering:
                    # enable bus mastering
                    val = yield from self.config_read_word(PcieId(bus, d, f), 0x04)
                    yield from self.config_write_word(PcieId(bus, d, f), 0x04, val | 4)

                if configure_msi:
                    # configure MSI
                    yield from self.configure_msi(PcieId(bus, d, f))

                if bridge:
                    # set bridge registers for enumeration
                    # logging
                    print("[%s] Set pri %d, sec %d, sub %d" % (highlight(self.get_desc()), bus, sec_bus, 255))

                    yield from self.config_write(PcieId(bus, d, f), 0x018, bytearray([bus, sec_bus, 255]))

                    # enumerate secondary bus
                    sub_bus = yield from self.enumerate_segment(tree=ti, bus=sec_bus, timeout=timeout, enable_bus_mastering=enable_bus_mastering, configure_msi=configure_msi)

                    # finalize bridge configuration
                    # logging
                    print("[%s] Set pri %d, sec %d, sub %d" % (highlight(self.get_desc()), bus, sec_bus, sub_bus))

                    yield from self.config_write(PcieId(bus, d, f), 0x018, bytearray([bus, sec_bus, sub_bus]))

                    # set base/limit registers
                    # logging
                    print("[%s] Set IO base: %08x, limit: %08x" % (highlight(self.get_desc()), ti.io_base, ti.io_limit))

                    yield from self.config_write(PcieId(bus, d, f), 0x01C, struct.pack('BB', (ti.io_base >> 8) & 0xf0, (ti.io_limit >> 8) & 0xf0))
                    yield from self.config_write(PcieId(bus, d, f), 0x030, struct.pack('<HH', ti.io_base >> 16, ti.io_limit >> 16))

                    # logging
                    print("[%s] Set mem base: %08x, limit: %08x" % (highlight(self.get_desc()), ti.mem_base, ti.mem_limit))

                    yield from self.config_write(PcieId(bus, d, f), 0x020, struct.pack('<HH', (ti.mem_base >> 16) & 0xfff0, (ti.mem_limit >> 16) & 0xfff0))

                    # logging
                    print("[%s] Set prefetchable mem base: %016x, limit: %016x" % (highlight(self.get_desc()), ti.prefetchable_mem_base, ti.prefetchable_mem_limit))

                    yield from self.config_write(PcieId(bus, d, f), 0x024, struct.pack('<HH', (ti.prefetchable_mem_base >> 16) & 0xfff0, (ti.prefetchable_mem_limit >> 16) & 0xfff0))
                    yield from self.config_write(PcieId(bus, d, f), 0x028, struct.pack('<L', ti.prefetchable_mem_base >> 32))
                    yield from self.config_write(PcieId(bus, d, f), 0x02c, struct.pack('<L', ti.prefetchable_mem_limit >> 32))

                    sec_bus = sub_bus+1

        tree.sub_bus_num = sub_bus

        # align limits against bridge registers
        self.io_limit = align(self.io_limit, 0xfff)
        self.mem_limit = align(self.mem_limit, 0xfffff)
        self.prefetchable_mem_limit = align(self.prefetchable_mem_limit, 0xfffff)

        tree.io_limit = self.io_limit-1
        tree.mem_limit = self.mem_limit-1
        tree.prefetchable_mem_limit = self.prefetchable_mem_limit-1

        # logging
        print("[%s] Enumeration of bus %d complete" % (highlight(self.get_desc()), bus))

        return sub_bus

    def enumerate(self, timeout=1000, enable_bus_mastering=False, configure_msi=False):
        # logging
        print("[%s] Enumerating bus" % (highlight(self.get_desc())))

        self.io_limit = self.io_base
        self.mem_limit = self.mem_base
        self.prefetchable_mem_limit = self.prefetchable_mem_base

        self.tree = TreeItem()
        yield from self.enumerate_segment(tree=self.tree, bus=0, timeout=timeout, enable_bus_mastering=enable_bus_mastering, configure_msi=configure_msi)

        self.upstream_bridge.io_base = self.io_base
        self.upstream_bridge.io_limit = self.io_limit
        self.upstream_bridge.mem_base = self.mem_base
        self.upstream_bridge.mem_limit = self.mem_limit
        self.upstream_bridge.prefetchable_mem_base = self.prefetchable_mem_base
        self.upstream_bridge.prefetchable_mem_limit = self.prefetchable_mem_limit

        # logging
        print("[%s] Enumeration complete" % (highlight(self.get_desc())))

        # logging
        print("Device tree:")
        print(self.tree.to_str().strip())

