.. _rb_flash_spi:

========================
SPI flash register block
========================

The SPI flash register block has a header with type 0x0000C120, version 0x00000200, and contains control registers for up to two SPI or QSPI flash chips.

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
    RBB+0x0C  Format         Format                          RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x10  Control 0              CS/CLK  OE      D       RW 0x00000000
    --------  -------------  ------  ------  ------  ------  -------------
    RBB+0x14  Control 1              CS/CLK  OE      D       RW 0x00000000
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
