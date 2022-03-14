.. _rb_flash_bpi:

========================
BPI flash register block
========================

The BPI flash register block has a header with type 0x0000C121, version 0x00000100, and contains control registers for a BPI flash chip.

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
    RBB+0x0C  Format         AW      DW      config          RO -
    --------  -------------  ------  ------  ------  ------  -------------
    RBB+0x10  Address        Address                         RW 0x00000000
    --------  -------------  ------------------------------  -------------
    RBB+0x14  Data           Data                            RW 0x00000000
    --------  -------------  ------------------------------  -------------
    RBB+0x18  Control                REGION  DQ_OE   CTRL    RW 0x0000000F
    ========  =============  ======  ======  ======  ======  =============

See :ref:`rb_overview` for definitions of the standard register block header fields.

.. object:: Format

    The format field contains information about the type and layout of the flash memory.  AW and DW indicate the address and data interface widths in bits, and config indicates the layout of the flash.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x0C  AW      DW      config          RO -
        ========  ======  ======  ======  ======  =============

    .. table::

        ======  =======================
        config  Configuration
        ======  =======================
        0x00    1 segment
        0x01    1 segment
        0x02    2 segments (even split)
        0x04    4 segments (even split)
        0x08    8 segments (even split)
        ======  =======================

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
