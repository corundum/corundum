.. _rb_overview:

===============
Register blocks
===============

The NIC register space is constructed from a linked list of register blocks.  Each block starts with a header that contains type, version, and next header fields.  Blocks must be DWORD aligned in the register space.  All fields must be naturally aligned.  All pointers in the register blocks are relative to the start of the region.  The list is terminated with a next pointer of 0x00000000.  See :numref:`tbl_rb_list` for a list of all currently-defined register blocks.

.. table::

    ========  ============  ======  ======  ======  ======  =============
    Address   Field         31..24  23..16  15..8   7..0    Reset value
    ========  ============  ======  ======  ======  ======  =============
    RBB+0x00  Type          Vendor ID       Type            RO -
    --------  ------------  --------------  --------------  -------------
    RBB+0x04  Version       Major   Minor   Patch   Meta    RO -
    --------  ------------  ------  ------  ------  ------  -------------
    RBB+0x08  Next pointer  Pointer to next register block  RO -
    ========  ============  ==============================  =============

.. object:: Type

    The type field consists of a vendor ID in the upper 16 bits, and the sub type in the lower 16 bits.  Vendor ID 0x0000 is used for all standard register blocks used by Corundum.  See :numref:`tbl_rb_list` for a list of all currently-defined register blocks.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x00  Vendor ID       Type            RO -
        ========  ==============  ==============  =============

.. object:: Version

    The version field consists of four fields, major, minor, patch, and meta.  Version numbers must be changed when backwards-incompatible changes are made to register blocks.  See :numref:`tbl_rb_list` for a list of all currently-defined register blocks.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x04  Major   Minor   Patch   Meta    RO -
        ========  ======  ======  ======  ======  =============

.. object:: Next pointer

    The next pointer field contains a block-relative offset to the start of the header of the next register block in the chain.  A next pointer of 0x00000000 indicates the end of the chain.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x08  Pointer to next register block  RO -
        ========  ==============================  =============

.. _tbl_rb_list:
.. table:: List of all currently-defined register blocks

    ==========  ==========  ======================
    Type        Version     Block
    ==========  ==========  ======================
    0x00000000  \-          :ref:`rb_null`
    0xFFFFFFFF  0x00000100  :ref:`rb_fw_id`
    0x0000C000  0x00000100  :ref:`rb_if`
    0x0000C001  0x00000400  :ref:`rb_if_ctrl`
    0x0000C002  0x00000200  port
    0x0000C003  0x00000200  port_ctrl
    0x0000C004  0x00000300  :ref:`rb_sched_block`
    0x0000C005  0x00000200  application
    0x0000C006  0x00000100  stats
    0x0000C007  0x00000100  IRQ config
    0x0000C008  0x00000100  Clock info
    0x0000C010  0x00000100  :ref:`rb_cqm_event`
    0x0000C020  0x00000100  :ref:`rb_qm_tx`
    0x0000C021  0x00000100  :ref:`rb_qm_rx`
    0x0000C030  0x00000100  :ref:`rb_cqm_tx`
    0x0000C031  0x00000100  :ref:`rb_cqm_rx`
    0x0000C040  0x00000100  :ref:`rb_sched_rr`
    0x0000C050  0x00000100  :ref:`rb_sched_ctrl_tdma`
    0x0000C060  0x00000100  :ref:`rb_tdma_sch`
    0x0000C080  0x00000100  :ref:`rb_phc`
    0x0000C081  0x00000100  :ref:`rb_phc_perout`
    0x0000C090  0x00000100  RX queue map
    0x0000C100  0x00000100  :ref:`rb_gpio`
    0x0000C110  0x00000100  :ref:`rb_i2c`
    0x0000C120  0x00000200  :ref:`rb_flash_spi`
    0x0000C121  0x00000200  :ref:`rb_flash_bpi`
    0x0000C140  0x00000100  :ref:`rb_bmc_alveo`
    0x0000C141  0x00000100  :ref:`rb_bmc_gecko`
    0x0000C150  0x00000100  :ref:`rb_drp`
    ==========  ==========  ======================

.. toctree::
    :maxdepth: 1
    :hidden:
    :glob:

    *
