.. _rb_bmc_gecko:

========================
Gecko BMC register block
========================

The Gecko BMC register block has a header with type 0x0000C141, version 0x00000100, and contains control registers for the Silicom Gecko BMC.

.. table::

    ========  =============  ======  ======  ======  ======  =============
    Address   Field          31..24  23..16  15..8   7..0    Reset value
    ========  =============  ======  ======  ======  ======  =============
    RBB+0x00  Type           Vendor ID       Type            RO 0x0000C141
    --------  -------------  --------------  --------------  -------------
    RBB+0x04  Version        Major   Minor   Patch   Meta    RO 0x00000100
    --------  -------------  ------  ------  ------  ------  -------------
    RBB+0x08  Next pointer   Pointer to next register block  RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x0C  Status         Status          Read data       RO 0x00000000
    --------  -------------  --------------  --------------  -------------
    RBB+0x10  Data           Write data                      RW 0x00000000
    --------  -------------  ------------------------------  -------------
    RBB+0x14  Command        Command                         RW 0x00000000
    ========  =============  ==============  ==============  =============

See :ref:`rb_overview` for definitions of the standard register block header fields.

.. object:: Status

    The status field provides status information and the read data from the BMC.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x0C  Status          Read data       RO 0x00000000
        ========  ==============  ==============  =============

    .. table::

        ===  ========
        Bit  Function
        ===  ========
        16   Done
        18   Timeout
        19   Idle
        ===  ========

.. object:: Data

    The data field provides the write data to the BMC.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x10  Write data                      RW 0x00000000
        ========  ==============================  =============

.. object:: Command

    The command field provides the command to the BMC.  Writing to the command field triggers an SPI transfer to the BMC.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x14  Command                         RW 0x00000000
        ========  ==============  ==============  =============
