.. _rb_if:

========================
Interface register block
========================

The interface register block has a header with type 0x0000C000, version 0x00000100, and indicates the number of interfaces present and where they are located in the control register space.

.. table::

    ========  =============  ======  ======  ======  ======  =============
    Address   Field          31..24  23..16  15..8   7..0    Reset value
    ========  =============  ======  ======  ======  ======  =============
    RBB+0x00  Type           Vendor ID       Type            RO 0x0000C000
    --------  -------------  --------------  --------------  -------------
    RBB+0x04  Version        Major   Minor   Patch   Meta    RO 0x00000100
    --------  -------------  ------  ------  ------  ------  -------------
    RBB+0x08  Next pointer   Pointer to next register block  RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x0C  Offset         Offset to first interface       RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x10  Count          Interface count                 RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x14  Stride         Interface stride                RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x18  CSR offset     Interface CSR offset            RO -
    ========  =============  ==============================  =============

See :ref:`rb_overview` for definitions of the standard register block header fields.

.. object:: Offset

    The offset field contains the offset to the start of the first interface region, relative to the start of the current region.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x0C  Offset to first interface       RO -
        ========  ==============================  =============

.. object:: Count

    The count field contains the number of interfaces.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x10  Interface count                 RO -
        ========  ==============================  =============

.. object:: Stride

    The stride field contains the size of the region for each interface.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x14  Interface stride                RO -
        ========  ==============================  =============

.. object:: CSR offset

    The CSR offset field contains the offset to the head of the register block chain inside of each interface's region.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x18  Interface CSR offset            RO -
        ========  ==============================  =============
