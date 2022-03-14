.. _rb_flash_spi:

========================
SPI flash register block
========================

The SPI flash register block has a header with type 0x0000C120, version 0x00000100, and contains control registers for up to two SPI or QSPI flash chips.

.. table::

    ========  =============  ======  ======  ======  ======  =============
    Address   Field          31..24  23..16  15..8   7..0    Reset value
    ========  =============  ======  ======  ======  ======  =============
    RBB+0x00  Type           Vendor ID       Type            RO 0x0000C120
    --------  -------------  --------------  --------------  -------------
    RBB+0x04  Version        Major   Minor   Patch   Meta    RO 0x00000100
    --------  -------------  ------  ------  ------  ------  -------------
    RBB+0x08  Next pointer   Pointer to next register block  RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x0C  Format         AW      DW      config          RO -
    --------  -------------  ------  ------  ------  ------  -------------
    RBB+0x10  Control 0              CS/CLK  OE      D       RW 0x00000000
    --------  -------------  ------  ------  ------  ------  -------------
    RBB+0x14  Control 1              CS/CLK  OE      D       RW 0x00000000
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

        ======  ================================
        config  Configuration
        ======  ================================
        0x00    1 segment
        0x01    1 segment
        0x02    2 segments (even split)
        0x04    4 segments (even split)
        0x08    8 segments (even split)
        0x81    2 segments (split at 0x01002000)
        ======  ================================

    .. table::

        ==  ==========
        DW  Flash type
        ==  ==========
        1   SPI
        4   QSPI
        8   Dual QSPI
        ==  ==========

.. object:: Control 0 and 1

    The control 0 and 1 fields each control one SPI/QSPI flash interface.  The second interface is only used in dual QSPI mode.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x10          CS/CLK  OE      D       RW 0x00000000
        --------  ------  ------  ------  ------  -------------
        RBB+0x14          CS/CLK  OE      D       RW 0x00000000
        ========  ======  ======  ======  ======  =============

    .. table::

        ===  =========
        Bit  Function
        ===  =========
        0    D0
        1    D1
        2    D2
        3    D3
        8    OE for D0
        9    OE for D1
        10   OE for D2
        11   OE for D3
        16   CLK
        17   CS_N
        ===  =========
