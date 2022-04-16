.. _rb_flash_bpi:

========================
BPI flash register block
========================

The BPI flash register block has a header with type 0x0000C121, version 0x00000200, and contains control registers for a BPI flash chip.

.. table::

    ========  =============  ======  ======  ======  ======  =============
    Address   Field          31..24  23..16  15..8   7..0    Reset value
    ========  =============  ======  ======  ======  ======  =============
    RBB+0x00  Type           Vendor ID       Type            RO 0x0000C121
    --------  -------------  --------------  --------------  -------------
    RBB+0x04  Version        Major   Minor   Patch   Meta    RO 0x00000100
    --------  -------------  ------  ------  ------  ------  -------------
    RBB+0x08  Next pointer   Pointer to next register block  RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x0C  Format         Format                          RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x10  Address        Address                         RW 0x00000000
    --------  -------------  ------------------------------  -------------
    RBB+0x14  Data           Data                            RW 0x00000000
    --------  -------------  ------------------------------  -------------
    RBB+0x18  Control                REGION  DQ_OE   CTRL    RW 0x0000000F
    ========  =============  ======  ======  ======  ======  =============

See :ref:`rb_overview` for definitions of the standard register block header fields.

.. object:: Format

    The format field contains information about the type and layout of the flash memory.  Bits 3:0 carry the number of segments.  Bits 7:4 carry the index of the default segment that carries the main FPGA configuration.  Bits 11:8 carry the index of the segment that contains a fallback FPGA configuration that is loaded if the configuration in the default segment fails to load.  Bits 31:12 contain the size of the first segment in increments of 4096 bytes, for two-segment configurations with an uneven split.  This field can be set to zero for an even split computed from the flash device size.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x0C  Format                          RO -
        ========  ======  ======  ======  ======  =============

    .. table::

        ======  ================================
        bits    Configuration
        ======  ================================
        3:0     Segment count
        7:4     Default segment
        11:8    Fallback segment
        31:12   First segment size
        ======  ================================

.. object:: Address

    The address field controls the address bus to the flash chip.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x10  Address                         RW 0x00000000
        ========  ==============================  =============

.. object:: Data

    The data field controls the data bus to the flash chip.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x14  Data                            RW 0x00000000
        ========  ==============================  =============

.. object:: Control

    The control field contains registers to drive all of the other flash control lines, as well as registers for output enables.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x18          REGION  DQ_OE   CTRL    RW 0x0000000F
        ========  ======  ======  ======  ======  =============

    .. table::

        ===  =========
        Bit  Function
        ===  =========
        0    CE_N
        1    OE_N
        2    WE_N
        3    ADV_N
        8    DQ_OE
        16   REGION_OE
        ===  =========
