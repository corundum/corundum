.. _rb_app_info:

=======================
App info register block
=======================

The app info register block has a header with type 0x0000C005, version 0x00000200, and contains the app ID of the application section.

.. table::

    ========  =============  ======  ======  ======  ======  =============
    Address   Field          31..24  23..16  15..8   7..0    Reset value
    ========  =============  ======  ======  ======  ======  =============
    RBB+0x00  Type           Vendor ID       Type            RO 0x0000C005
    --------  -------------  --------------  --------------  -------------
    RBB+0x04  Version        Major   Minor   Patch   Meta    RO 0x00000200
    --------  -------------  ------  ------  ------  ------  -------------
    RBB+0x08  Next pointer   Pointer to next register block  RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x0C  App ID         App ID                          RO -
    ========  =============  ==============================  =============

See :ref:`rb_overview` for definitions of the standard register block header fields.

.. object:: App ID

    The app ID field contains the app ID of the application section.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x0C  App ID                          RO -
        ========  ==============================  =============
