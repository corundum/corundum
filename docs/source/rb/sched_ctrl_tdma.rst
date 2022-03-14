.. _rb_sched_ctrl_tdma:

========================================
TDMA scheduler controller register block
========================================

The TDMA scheduler controller register block has a header with type 0x0000C050, version 0x00000100, and indicates the location of the scheduler controller in the register space, as well as containing some control, status, and informational registers.

.. table::

    ========  =============  ======  ======  ======  ======  =============
    Address   Field          31..24  23..16  15..8   7..0    Reset value
    ========  =============  ======  ======  ======  ======  =============
    RBB+0x00  Type           Vendor ID       Type            RO 0x0000C050
    --------  -------------  --------------  --------------  -------------
    RBB+0x04  Version        Major   Minor   Patch   Meta    RO 0x00000100
    --------  -------------  ------  ------  ------  ------  -------------
    RBB+0x08  Next pointer   Pointer to next register block  RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x0C  Offset         Offset to scheduler             RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x10  CH count       Channel count                   RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x14  CH stride      Channel stride                  RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x18  Control        Control                         RW 0x00000000
    --------  -------------  ------------------------------  -------------
    RBB+0x1C  TS count       TS count                        RW -
    ========  =============  ==============================  =============

See :ref:`rb_overview` for definitions of the standard register block header fields.

.. object:: Offset

    The offset field contains the offset to the start of the scheduler, relative to the start of the current region.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x0C  Offset to scheduler             RO -
        ========  ==============================  =============

.. object:: Channel count

    The channel count field contains the number of channels.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x10  Channel count                   RO -
        ========  ==============================  =============

.. object:: Channel stride

    The channel stride field contains the size of the region for each channel.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x14  Channel stride                  RO -
        ========  ==============================  =============

.. object:: Control

    The control field contains scheduler-related control bits.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x18  Control                         RW 0x00000000
        ========  ==============================  =============

.. object:: Timeslot count

    The timeslot count register contains the number of time slots supported.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x1C  Timeslot count                  RO -
        ========  ==============================  =============

TDMA scheduler controller CSRs
==============================

Each scheduler control channel has several associated control registers, detailed in this table:

.. table::

    =========  ==============  ======  ======  ======  ======  =============
    Address    Field           31..24  23..16  15..8   7..0    Reset value
    =========  ==============  ======  ======  ======  ======  =============
    Base+0x00  Enable bits     Enable bits                     RW -
    ---------  --------------  ------------------------------  -------------
    Base+N     Enable bits     Enable bits                     RW -
    =========  ==============  ==============================  =============

.. object:: Enable bits

    The enable bits field contains per-timeslot channel enable bits.

    .. table::

        =========  ======  ======  ======  ======  =============
        Address    31..24  23..16  15..8   7..0    Reset value
        =========  ======  ======  ======  ======  =============
        Base+0x00  Enable bits                     RW 0x00000000
        =========  ==============================  =============

    .. table::

        ===  =================
        Bit  Function
        ===  =================
        0    Timeslot 0 enable
        N    Timeslot N enable
        ===  =================
