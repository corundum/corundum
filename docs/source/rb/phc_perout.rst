.. _rb_phc_perout:

================================
PTP period output register block
================================

The PTP period output register block has a header with type 0x0000C081, version 0x00000100, and carries several control registers for the PTP period output module.

.. table::

    ========  ==============  ======  ======  ======  ======  =============
    Address   Field           31..24  23..16  15..8   7..0    Reset value
    ========  ==============  ======  ======  ======  ======  =============
    RBB+0x00  Type            Vendor ID       Type            RO 0x0000C081
    --------  --------------  --------------  --------------  -------------
    RBB+0x04  Version         Major   Minor   Patch   Meta    RO 0x00000100
    --------  --------------  ------  ------  ------  ------  -------------
    RBB+0x08  Next pointer    Pointer to next register block  RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x0C  Control         Control                         RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x10  Start time      Start time (fractional ns)      RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x14  Start time      Start time (ns)                 RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x18  Start time      Start time (sec, lower 32)      RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x1C  Start time      Start time (sec, upper 32)      RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x20  Period          Period (fractional ns)          RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x24  Period          Period (ns)                     RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x28  Period          Period (sec, lower 32)          RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x2C  Period          Period (sec, upper 32)          RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x30  Width           Width (fractional ns)           RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x34  Width           Width (ns)                      RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x38  Width           Width (sec, lower 32)           RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x3C  Width           Width (sec, upper 32)           RW -
    ========  ==============  ==============================  =============

See :ref:`rb_overview` for definitions of the standard register block header fields.

.. object:: Control

    The control register contains several control and status bits relating to the operation of the period output module.

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
        0    Enable
        8    Pulse
        16   Locked
        24   Error
        ===  ========

    The enable bit enables/disables output of the period output module.  Note that this bit does not cause the module to lose lock when clear, only to stop generating pulses.

    The pulse bit reflects the current output of the PTP period output module.

    The locked bit indicates that the period output module has locked on to the current PTP time and is ready to generate pulses.  The output is disabled while the period output module is unlocked, so it is not necessary to wait for the module to lock before enabling the output.  The module will unlock whenever the start time, period, or width setting is changed.

    The error bit indicates that the period output module came out of lock due to the PTP clock being stepped.  The error bit is self-clearing on either reacquisition of lock or a setting change.

    The period output module keeps track of the times for the next rising edge and next falling edge.  Initially, it starts with the specified start time for the rising edge, and start time plus width for the falling edge.  If the computed next rising edge time is in the past, the period will be added and it will be checked again, repeating this process until the next rising edge is in the future.  Note that the period is added once per clock cycle, so it is recommended to compute a start time that is close to the current time, particularly when using a small period setting, so that the period output module can lock quickly.

.. object:: Start time

    The start time registers determine the absolute start time for the output waveform (rising edge), with all values latched coincident with writing the upper 32 bits of the seconds field.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x10  Start time (fractional ns)      RW -
        --------  ------------------------------  -------------
        RBB+0x14  Start time (ns)                 RW -
        --------  ------------------------------  -------------
        RBB+0x18  Start time (sec, lower 32)      RW -
        --------  ------------------------------  -------------
        RBB+0x1C  Start time (sec, upper 32)      RW -
        ========  ==============================  =============

.. object:: Period

    The period registers control the period of the output waveform (rising edge to rising edge), with all values latched coincident with writing the upper 32 bits of the seconds field.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x20  Period (fractional ns)          RW -
        --------  ------------------------------  -------------
        RBB+0x24  Period (ns)                     RW -
        --------  ------------------------------  -------------
        RBB+0x28  Period (sec, lower 32)          RW -
        --------  ------------------------------  -------------
        RBB+0x2C  Period (sec, upper 32)          RW -
        ========  ==============================  =============

.. object:: Width

    The width registers control the width of the output waveform (rising edge to falling edge), with all values latched coincident with writing the upper 32 bits of the seconds field.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x30  Width (fractional ns)           RW -
        --------  ------------------------------  -------------
        RBB+0x34  Width (ns)                      RW -
        --------  ------------------------------  -------------
        RBB+0x38  Width (sec, lower 32)           RW -
        --------  ------------------------------  -------------
        RBB+0x3C  Width (sec, upper 32)           RW -
        ========  ==============================  =============
