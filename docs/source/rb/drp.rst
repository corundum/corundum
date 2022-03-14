.. _rb_drp:

==================
DRP register block
==================

The DRP register block has a header with type 0x0000C150, version 0x00000100, and contains control registers for a Xilinx dynamic reconfiguration port (DRP).

.. table::

    ========  =============  ======  ======  ======  ======  =============
    Address   Field          31..24  23..16  15..8   7..0    Reset value
    ========  =============  ======  ======  ======  ======  =============
    RBB+0x00  Type           Vendor ID       Type            RO 0x0000C150
    --------  -------------  --------------  --------------  -------------
    RBB+0x04  Version        Major   Minor   Patch   Meta    RO 0x00000100
    --------  -------------  ------  ------  ------  ------  -------------
    RBB+0x08  Next pointer   Pointer to next register block  RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x0C  DRP info       DRP info                        RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x10  Control        Control                         RW 0x00000000
    --------  -------------  ------------------------------  -------------
    RBB+0x14  Address        Address                         RW 0x00000000
    --------  -------------  ------------------------------  -------------
    RBB+0x18  Write data     Write data                      RW 0x00000000
    --------  -------------  ------------------------------  -------------
    RBB+0x1C  Read data      Read data                       RO 0x00000000
    ========  =============  ==============================  =============

See :ref:`rb_overview` for definitions of the standard register block header fields.

.. object:: DRP info

    The DRP info field contains identifying information about the component(s) accessible via the DRP interface.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x0C  DRP info                        RO -
        ========  ==============================  =============

.. object:: Control

    The control field is used to trigger read and write operations on the DRP interface.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x10  Control                         RW 0x00000000
        ========  ==============================  =============

    .. table::

        ===  ========
        Bit  Function
        ===  ========
        0    Enable
        1    Write
        8    Busy
        ===  ========

    To issue a read operation, set the address register and then write 0x00000001 to the control register.  Wait for the enable and busy bits to self-clear, then read the data from the read data register.

    To issue a write operation, set the address register and write data register appropriately, then write 0x00000003 to the control register.  Wait for the enable and busy bits to self-clear.

.. object:: Address

    The address field controls the address for DRP operations.  This address is directly presented on the DRP interface.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x14  Address                         RW 0x00000000
        ========  ==============================  =============

.. object:: Write data

    The write data field contains the data used for DRP write operations.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x18  Write data                      RW 0x00000000
        ========  ==============================  =============

.. object:: Read data

    The read data field contains the data returned by DRP read operations.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x1C  Read data                       RO 0x00000000
        ========  ==============================  =============
