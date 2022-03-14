.. _rb_fw_id:

==========================
Firmware ID register block
==========================

The firmware ID register block has a header with type 0xFFFFFFFF, version 0x00000100, and carries several pieces of information related to the firmware version and build.

.. table::

    ========  =============  ======  ======  ======  ======  =============
    Address   Field          31..24  23..16  15..8   7..0    Reset value
    ========  =============  ======  ======  ======  ======  =============
    RBB+0x00  Type           Vendor ID       Type            RO 0xFFFFFFFF
    --------  -------------  --------------  --------------  -------------
    RBB+0x04  Version        Major   Minor   Patch   Meta    RO 0x00000100
    --------  -------------  ------  ------  ------  ------  -------------
    RBB+0x08  Next pointer   Pointer to next register block  RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x0C  FPGA ID        JTAG ID                         RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x10  FW ID          Vendor ID       Firmware ID     RO -
    --------  -------------  --------------  --------------  -------------
    RBB+0x14  FW Version     Major   Minor   Patch   Meta    RO -
    --------  -------------  ------  ------  ------  ------  -------------
    RBB+0x18  Board ID       Vendor ID       Board ID        RO -
    --------  -------------  --------------  --------------  -------------
    RBB+0x1C  Board Version  Major   Minor   Patch   Meta    RO -
    --------  -------------  ------  ------  ------  ------  -------------
    RBB+0x20  Build date     Build date                      RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x24  Git hash       Commit hash                     RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x28  Release info   Release info                    RO -
    ========  =============  ==============================  =============

See :ref:`rb_overview` for definitions of the standard register block header fields.

.. object:: FPGA ID

    The FPGA ID field contains the JTAG ID of the target device.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x0C  JTAG ID                         RO -
        ========  ==============================  =============

.. object:: Firmware ID

    The firmware ID field consists of a vendor ID in the upper 16 bits, and the firmware ID in the lower 16 bits.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x10  Vendor ID       Firmware ID     RO -
        ========  ==============  ==============  =============

.. object:: Firmware version

    The firmware version field consists of four fields, major, minor, patch, and meta.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x14  Major   Minor   Patch   Meta    RO -
        ========  ======  ======  ======  ======  =============

.. object:: Board ID

    The board ID field consists of a vendor ID in the upper 16 bits, and the board ID in the lower 16 bits.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x18  Vendor ID       Board ID        RO -
        ========  ==============  ==============  =============

.. object:: Board version

    The board version field consists of four fields, major, minor, patch, and meta.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x1C  Major   Minor   Patch   Meta    RO -
        ========  ======  ======  ======  ======  =============

.. object:: Build date

    The build date field contains the Unix timestamp of the start of the build as an unsigned 32-bit integer.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x20  Build date                      RO -
        ========  ==============================  =============

.. object:: Git hash

    The git hash field contains the upper 32 bits of the git commit hash.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x24  Commit hash                     RO -
        ========  ==============================  =============

.. object:: Release info

    The release info field is reserved for additional release information.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x28  Release info                    RO -
        ========  ==============================  =============
