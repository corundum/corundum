.. _rb_bmc_alveo:

========================
Alveo BMC register block
========================

The Alveo BMC register block has a header with type 0x0000C140, version 0x00000100, and contains control registers for the `Xilinx Alveo CMS IP <https://www.xilinx.com/products/intellectual-property/cms-subsystem.html>`_.

.. table::

    ========  =============  ======  ======  ======  ======  =============
    Address   Field          31..24  23..16  15..8   7..0    Reset value
    ========  =============  ======  ======  ======  ======  =============
    RBB+0x00  Type           Vendor ID       Type            RO 0x0000C140
    --------  -------------  --------------  --------------  -------------
    RBB+0x04  Version        Major   Minor   Patch   Meta    RO 0x00000100
    --------  -------------  ------  ------  ------  ------  -------------
    RBB+0x08  Next pointer   Pointer to next register block  RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x0C  Address        Address                         RW 0x00000000
    --------  -------------  ------------------------------  -------------
    RBB+0x10  Data           Data                            RW 0x00000000
    ========  =============  ==============================  =============

See :ref:`rb_overview` for definitions of the standard register block header fields.

.. object:: Address

    The address field controls the address bus to the CMS IP core.  Writing to this register triggers a read of the corresponding address via the AXI-lite interface to the CMS IP.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x0C  Address                         RW 0x00000000
        ========  ==============================  =============

.. object:: Data

    The data field controls the data bus to the CMS IP core.  Writing to this register triggers a write to the address specified by the address register via the AXI-lite interface to the CMS IP.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x10  Data                            RW 0x00000000
        ========  ==============================  =============
