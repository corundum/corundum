.. _rb_phc:

=================================
PTP hardware clock register block
=================================

The PTP hardware clock register block has a header with type 0x0000C080, version 0x00000100, and carries several control registers for the PTP clock.

.. table::

    ========  ==============  ======  ======  ======  ======  =============
    Address   Field           31..24  23..16  15..8   7..0    Reset value
    ========  ==============  ======  ======  ======  ======  =============
    RBB+0x00  Type            Vendor ID       Type            RO 0x0000C080
    --------  --------------  --------------  --------------  -------------
    RBB+0x04  Version         Major   Minor   Patch   Meta    RO 0x00000100
    --------  --------------  ------  ------  ------  ------  -------------
    RBB+0x08  Next pointer    Pointer to next register block  RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x0C  Control         Control                         RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x10  Current time    Current time (fractional ns)    RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x14  Current time    Current time (ns)               RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x18  Current time    Current time (sec, lower 32)    RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x1C  Current time    Current time (sec, upper 32)    RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x20  Get time        Get time (fractional ns)        RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x24  Get time        Get time (ns)                   RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x28  Get time        Get time (sec, lower 32)        RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x2C  Get time        Get time (sec, upper 32)        RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x30  Set time        Set time (fractional ns)        RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x34  Set time        Set time (ns)                   RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x38  Set time        Set time (sec, lower 32)        RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x3C  Set time        Set time (sec, upper 32)        RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x40  Period          Period (fractional ns)          RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x44  Period          Period (ns)                     RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x48  Nominal period  Nominal period (fractional ns)  RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x4C  Nominal period  Nominal period (ns)             RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x50  Adj time        Adj time (fractional ns)        RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x54  Adj time        Adj time (ns)                   RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x58  Adj time count  Adj time cycle count            RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x5C  Adj time act    Adj time active                 RO -
    ========  ==============  ==============================  =============

See :ref:`rb_overview` for definitions of the standard register block header fields.

.. object:: Current time

    The current time registers read the current time from the PTP clock, with no double-buffering.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x10  Current time (fractional ns)    RO -
        --------  ------------------------------  -------------
        RBB+0x14  Current time (ns)               RO -
        --------  ------------------------------  -------------
        RBB+0x18  Current time (sec, lower 32)    RO -
        --------  ------------------------------  -------------
        RBB+0x1C  Current time (sec, upper 32)    RO -
        ========  ==============================  =============

.. object:: Get time

    The get time registers read the current time from the PTP clock, with all values latched coincident with reading the fractional ns register.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x20  Get time (fractional ns)        RO -
        --------  ------------------------------  -------------
        RBB+0x24  Get time (ns)                   RO -
        --------  ------------------------------  -------------
        RBB+0x28  Get time (sec, lower 32)        RO -
        --------  ------------------------------  -------------
        RBB+0x2C  Get time (sec, upper 32)        RO -
        ========  ==============================  =============

.. object:: Set time

    The set time registers set the current time on the PTP clock, with all values latched coincident with writing the upper 32 bits of the seconds field.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x30  Set time (fractional ns)        RW -
        --------  ------------------------------  -------------
        RBB+0x34  Set time (ns)                   RW -
        --------  ------------------------------  -------------
        RBB+0x38  Set time (sec, lower 32)        RW -
        --------  ------------------------------  -------------
        RBB+0x3C  Set time (sec, upper 32)        RW -
        ========  ==============================  =============

.. object:: Period

    The period registers control the period of the PTP clock, with all values latched coincident with writing the ns field.  The period value is accumulated into the PTP clock on every clock cycle.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x40  Period (fractional ns)          RW -
        --------  ------------------------------  -------------
        RBB+0x44  Period (ns)                     RW -
        ========  ==============================  =============

.. object:: Nominal period

    The nominal period registers contain the nominal period of the PTP clock, which corresponds to zero frequency offset in the ideal case.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x48  Nominal period (fractional ns)  RO -
        --------  ------------------------------  -------------
        RBB+0x4C  Nominal period (ns)             RO -
        ========  ==============================  =============

.. object:: Adjust time

    The adjust time registers can be used to slew the clock over some time period.  An adjustment can be specified with some amount of time added every clock cycle for N cycles.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x50  Adj time (fractional ns)        RW -
        --------  ------------------------------  -------------
        RBB+0x54  Adj time (ns)                   RW -
        --------  ------------------------------  -------------
        RBB+0x58  Adj time cycle count            RW -
        --------  ------------------------------  -------------
        RBB+0x5C  Adj time active                 RO -
        ========  ==============================  =============
