.. _rb_phc:

=================================
PTP hardware clock register block
=================================

The PTP hardware clock register block has a header with type 0x0000C080, version 0x00000200, and carries several control registers for the PTP clock.

.. table::

    ========  ==============  ======  ======  ======  ======  =============
    Address   Field           31..24  23..16  15..8   7..0    Reset value
    ========  ==============  ======  ======  ======  ======  =============
    RBB+0x00  Type            Vendor ID       Type            RO 0x0000C080
    --------  --------------  --------------  --------------  -------------
    RBB+0x04  Version         Major   Minor   Patch   Meta    RO 0x00000200
    --------  --------------  ------  ------  ------  ------  -------------
    RBB+0x08  Next pointer    Pointer to next register block  RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x0C  Control         Control                         RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x10  Current FNS     Current fractional ns           RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x14  Current ToD     Current ToD (ns)                RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x18  Current ToD     Current ToD (sec, lower 32)     RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x1C  Current ToD     Current ToD (sec, upper 16)     RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x20  Current rel     Current rel. (ns, lower 32)     RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x24  Current rel     Current rel. (ns, upper 16)     RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x28  Current PTM     Current PTM (ns, lower 32)      RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x2C  Current PTM     Current PTM (ns, upper 32)      RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x30  Snapshot FNS    Snapshot fractional ns          RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x34  Snapshot ToD    Snapshot ToD (ns)               RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x38  Snapshot ToD    Snapshot ToD (sec, lower 32)    RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x3C  Snapshot ToD    Snapshot ToD (sec, upper 16)    RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x40  Snapshot rel    Snapshot rel. (ns, lower 32)    RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x44  Snapshot rel    Snapshot rel. (ns, upper 16)    RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x48  Snapshot PTM    Snapshot PTM (ns, lower 32)     RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x4C  Snapshot PTM    Snapshot PTM (ns, upper 32)     RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x50  Offset ToD      Offset ToD (ns)                 RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x54  Set ToD         Set ToD (ns)                    RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x58  Set ToD         Set ToD (sec, lower 32)         RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x5C  Set ToD         Set ToD (sec, upper 16)         RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x60  Set rel         Set rel. (ns, lower 32)         RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x64  Set rel         Set rel. (ns, upper 16)         RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x68  Offset rel      Offset relative (ns)            RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x6C  Offset FNS      Offset FNS (fns)                RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x70  Nominal period  Nominal period (fractional ns)  RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x74  Nominal period  Nominal period (ns)             RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x78  Period          Period (fractional ns)          RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x7C  Period          Period (ns)                     RW -
    ========  ==============  ==============================  =============

See :ref:`rb_overview` for definitions of the standard register block header fields.

.. object:: Control

    The control register contains several control and status bits relating to the operation of the PTP hardware clock.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x0C  Control                         RW -
        ========  ==============================  =============

    .. table::

        ===  ========
        Bit  Function
        ===  ========
        8    PPS pulse
        16   Locked
        24   Set ToD pending
        25   Offset ToD pending
        26   Set Relative pending
        27   Offset Relative pending
        28   Set Period pending
        29   Offset FNS pending
        ===  ========

    The PPS pulse bit reflects the current value of the stretched PPS output (rising edge is the active edge).

    The locked bit indicates that the PTP CDC logic between the PTP clock domain and the core clock domain is locked, and therefore the times in the current and snapshot registers are valid.

    The pending bits indicate that a set or offset has been requested, but has not yet been applied.

.. object:: Current time

    The current time registers read the current time from the PTP clock, with no double-buffering.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x10  Current fractional ns           RO -
        --------  ------------------------------  -------------
        RBB+0x14  Current ToD (ns)                RO -
        --------  ------------------------------  -------------
        RBB+0x18  Current ToD (sec, lower 32)     RO -
        --------  ------------------------------  -------------
        RBB+0x1C  Current ToD (sec, upper 16)     RO -
        --------  ------------------------------  -------------
        RBB+0x20  Current rel. (ns, lower 32)     RO -
        --------  ------------------------------  -------------
        RBB+0x24  Current rel. (ns, upper 16)     RO -
        --------  ------------------------------  -------------
        RBB+0x28  Current PTM (ns, lower 32)      RO -
        --------  ------------------------------  -------------
        RBB+0x2C  Current PTM (ns, upper 32)      RO -
        ========  ==============================  =============

.. object:: Snapshot time

    The get time registers read the current time from the PTP clock, with all values latched coincident with reading the fractional ns register.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x30  Snapshot fractional ns          RO -
        --------  ------------------------------  -------------
        RBB+0x34  Snapshot ToD (ns)               RO -
        --------  ------------------------------  -------------
        RBB+0x38  Snapshot ToD (sec, lower 32)    RO -
        --------  ------------------------------  -------------
        RBB+0x3C  Snapshot ToD (sec, upper 16)    RO -
        --------  ------------------------------  -------------
        RBB+0x40  Snapshot rel. (ns, lower 32)    RO -
        --------  ------------------------------  -------------
        RBB+0x44  Snapshot rel. (ns, upper 16)    RO -
        --------  ------------------------------  -------------
        RBB+0x48  Snapshot PTM (ns, lower 32)     RO -
        --------  ------------------------------  -------------
        RBB+0x4C  Snapshot PTM (ns, upper 32)     RO -
        ========  ==============================  =============

.. object:: Set time

    The set time registers set the current time on the PTP clock, while the offset registers can be used to apply precise steps to the PTP clock.  The ToD setting is applied when the upper 16 bits of the seconds field is written, and the relative setting is applied when the upper 16 bits of the ns field is written.  The FNS and relative offset fields are 32 bit signed integers, while the ToD offset is a 30 bit signed integer with the two MSBs ignored.  Offsets are applied immediately and atomically upon writing to the corresponding register.  These registers are read-only while updates are pending, pending status is reported in the control register.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x50  Offset ToD (ns)                 RW -
        --------  ------------------------------  -------------
        RBB+0x54  Set ToD (ns)                    RW -
        --------  ------------------------------  -------------
        RBB+0x58  Set ToD (sec, lower 32)         RW -
        --------  ------------------------------  -------------
        RBB+0x5C  Set ToD (sec, upper 16)         RW -
        --------  ------------------------------  -------------
        RBB+0x60  Set rel. (ns, lower 32)         RW -
        --------  ------------------------------  -------------
        RBB+0x64  Set rel. (ns, upper 16)         RW -
        --------  ------------------------------  -------------
        RBB+0x68  Offset relative (ns)            RW -
        --------  ------------------------------  -------------
        RBB+0x6C  Offset FNS (fns)                RW -
        ========  ==============================  =============

.. object:: Nominal period

    The nominal period registers contain the nominal period of the PTP clock, which corresponds to zero frequency offset in the ideal case.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x70  Nominal period (fractional ns)  RO -
        --------  ------------------------------  -------------
        RBB+0x74  Nominal period (ns)             RO -
        ========  ==============================  =============

.. object:: Period

    The period registers control the period of the PTP clock, with all values latched coincident with writing the ns field.  The period value is accumulated into the PTP clock on every clock cycle, and applies to both the relative and ToD timestamps.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x78  Period (fractional ns)          RW -
        --------  ------------------------------  -------------
        RBB+0x7C  Period (ns)                     RW -
        ========  ==============================  =============
