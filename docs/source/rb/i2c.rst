.. _rb_i2c:

===================
I2C register block
===================

The I2C register block has a header with type 0x0000C110, version 0x00000100, and contains registers to control an I2C interface.

.. table::

    ========  =============  ======  ======  ======  ======  =============
    Address   Field          31..24  23..16  15..8   7..0    Reset value
    ========  =============  ======  ======  ======  ======  =============
    RBB+0x00  Type           Vendor ID       Type            RO 0x0000C110
    --------  -------------  --------------  --------------  -------------
    RBB+0x04  Version        Major   Minor   Patch   Meta    RO 0x00000100
    --------  -------------  ------  ------  ------  ------  -------------
    RBB+0x08  Next pointer   Pointer to next register block  RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x0C  Control        Mux control     SDA     SCL     RW 0x00000303
    ========  =============  ==============  ======  ======  =============

See :ref:`rb_overview` for definitions of the standard register block header fields.

.. object:: Control

    The control field has bits to control SCL, SDA, and any associated multiplexers/switches.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x0C  Mux control     SDA     SCL     RW 0x00000303
        ========  ==============  ======  ======  =============

    .. table::

        ===  ========
        Bit  Function
        ===  ========
        0    SCL in
        1    SCL out
        8    SDA in
        9    SDA out
        ===  ========
