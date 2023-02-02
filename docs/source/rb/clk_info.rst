.. _rb_clk_info:

=========================
Clock info register block
=========================

The clock info register block has a header with type 0x0000C008, version 0x00000100, and contains information about clocks in the design.

.. table::

    ===========  =============  ======  ======  ======  ======  =============
    Address      Field          31..24  23..16  15..8   7..0    Reset value
    ===========  =============  ======  ======  ======  ======  =============
    RBB+0x00     Type           Vendor ID       Type            RO 0x0000C008
    -----------  -------------  --------------  --------------  -------------
    RBB+0x04     Version        Major   Minor   Patch   Meta    RO 0x00000100
    -----------  -------------  ------  ------  ------  ------  -------------
    RBB+0x08     Next pointer   Pointer to next register block  RO -
    -----------  -------------  ------------------------------  -------------
    RBB+0x0C     Channel count  Channel count                   RO -
    -----------  -------------  ------------------------------  -------------
    RBB+0x10     Ref period     Ref per num     Ref per denom   RO -
    -----------  -------------  --------------  --------------  -------------
    RBB+0x18     Clk period     Clk per num     Clk per denom   RO -
    -----------  -------------  --------------  --------------  -------------
    RBB+0x1C     Clk freq       Core clock frequency (Hz)       RO -
    -----------  -------------  ------------------------------  -------------
    RBB+0x20+4n  Channel freq   Channel clock frequency (Hz)    RO -
    ===========  =============  ==============================  =============

See :ref:`rb_overview` for definitions of the standard register block header fields.

.. object:: Channel count

    The channel count field contains the number of clocks, excluding the core and reference clocks.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x0C  Channel count                   RO -
        ========  ==============================  =============

.. object:: Reference clock period

    The reference clock period field contains the nominal period of the reference clock in nanoseconds as a fractional value, consisting of a 16-bit numerator and a 16-bit denominator.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x10  Ref per num     Ref per denom   RO -
        ========  ==============  ==============  =============

.. object:: Core clock period

    The core clock period field contains the nominal period of the core clock in nanoseconds as a fractional value, consisting of a 16-bit numerator and a 16-bit denominator.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x18  Clk per num     Clk per denom   RO -
        ========  ==============  ==============  =============

.. object:: Core clock frequency

    The core clock frequency field contains the measured core clock frequency in Hz, measured relative to the reference clock.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x1C  Core clock frequency (Hz)       RO -
        ========  ==============================  =============

.. object:: Channel clock frequency

    The channel clock frequency fields contain the measured channel clock frequency in Hz, measured relative to the reference clock.  There is one register per channel.

    .. table::

        ===========  ======  ======  ======  ======  =============
        Address      31..24  23..16  15..8   7..0    Reset value
        ===========  ======  ======  ======  ======  =============
        RBB+0x20+4n  Channel clock frequency (Hz)    RO -
        ===========  ==============================  =============
