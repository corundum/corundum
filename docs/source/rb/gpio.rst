.. _rb_gpio:

===================
GPIO register block
===================

The GPIO register block has a header with type 0x0000C100, version 0x00000100, and contains GPIO control registers.

========  =============  ======  ======  ======  ======  =============
Address   Field          31..24  23..16  15..8   7..0    Reset value
========  =============  ======  ======  ======  ======  =============
RBB+0x00  Type           Vendor ID       Type            RO 0x0000C100
--------  -------------  --------------  --------------  -------------
RBB+0x04  Version        Major   Minor   Patch   Meta    RO 0x00000100
--------  -------------  ------  ------  ------  ------  -------------
RBB+0x08  Next pointer   Pointer to next register block  RO -
--------  -------------  ------------------------------  -------------
RBB+0x0C  GPIO in        GPIO in                         RO -
--------  -------------  ------------------------------  -------------
RBB+0x10  GPIO out       GPIO out                        RW -
========  =============  ==============================  =============

See :ref:`rb_overview` for definitions of the standard register block header fields.

.. object:: GPIO in

    The GPIO in field reads the input signal states.

    ========  ======  ======  ======  ======  =============
    Address   31..24  23..16  15..8   7..0    Reset value
    ========  ======  ======  ======  ======  =============
    RBB+0x0C  GPIO in                         RO -
    ========  ==============================  =============

.. object:: GPIO out

    The GPIO out field controls the output signal states.

    ========  ======  ======  ======  ======  =============
    Address   31..24  23..16  15..8   7..0    Reset value
    ========  ======  ======  ======  ======  =============
    RBB+0x10  GPIO out                        RW -
    ========  ==============================  =============
