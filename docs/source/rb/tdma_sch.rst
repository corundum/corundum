.. _rb_tdma_sch:

=============================
TDMA scheduler register block
=============================

The TDMA scheduler register block has a header with type 0x0000C060, version 0x00000100, and carries several control registers for the TDMA scheduler module.

.. table::

    ========  ==============  ======  ======  ======  ======  =============
    Address   Field           31..24  23..16  15..8   7..0    Reset value
    ========  ==============  ======  ======  ======  ======  =============
    RBB+0x00  Type            Vendor ID       Type            RO 0x0000C060
    --------  --------------  --------------  --------------  -------------
    RBB+0x04  Version         Major   Minor   Patch   Meta    RO 0x00000100
    --------  --------------  ------  ------  ------  ------  -------------
    RBB+0x08  Next pointer    Pointer to next register block  RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x0C  TS count        Timeslot count                  RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x10  Control         Control                         RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x14  Status          Status                          RO -
    --------  --------------  ------------------------------  -------------
    RBB+0x20  Sch start       Sch start time (fractional ns)  RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x24  Sch start       Sch start time (ns)             RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x28  Sch start       Sch start time (sec, lower 32)  RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x2C  Sch start       Sch start time (sec, upper 32)  RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x30  Sch period      Sch period (fractional ns)      RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x34  Sch period      Sch period (ns)                 RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x38  Sch period      Sch period (sec, lower 32)      RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x3C  Sch period      Sch period (sec, upper 32)      RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x40  TS period       TS period (fractional ns)       RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x44  TS period       TS period (ns)                  RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x48  TS period       TS period (sec, lower 32)       RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x4C  TS period       TS period (sec, upper 32)       RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x50  Active period   Active period (fractional ns)   RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x54  Active period   Active period (ns)              RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x58  Active period   Active period (sec, lower 32)   RW -
    --------  --------------  ------------------------------  -------------
    RBB+0x5C  Active period   Active period (sec, upper 32)   RW -
    ========  ==============  ==============================  =============

See :ref:`rb_overview` for definitions of the standard register block header fields.

.. object:: Timeslot count

    The timeslot count register contains the number of time slots supported.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x0C  Timeslot count                  RO -
        ========  ==============================  =============

.. object:: Control

    The control register contains several control bits relating to the operation of the TDMA scheduler module.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x10  Control                         RW -
        ========  ==============================  =============

    .. table::

        ===  ========
        Bit  Function
        ===  ========
        0    Enable
        ===  ========

.. object:: Status

    The control register contains several status bits relating to the operation of the TDMA scheduler module.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x14  Status                          RO -
        ========  ==============================  =============

    .. table::

        ===  ========
        Bit  Function
        ===  ========
        0    Locked
        1    Error
        ===  ========

.. object:: Schedule start time

    The schedule start time registers determine the absolute start time for the schedule, with all values latched coincident with writing the upper 32 bits of the seconds field.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x20  Sch start time (fractional ns)  RW -
        --------  ------------------------------  -------------
        RBB+0x24  Sch start time (ns)             RW -
        --------  ------------------------------  -------------
        RBB+0x28  Sch start time (sec, lower 32)  RW -
        --------  ------------------------------  -------------
        RBB+0x2C  Sch start time (sec, upper 32)  RW -
        ========  ==============================  =============

.. object:: Schedule period

    The schedule period registers control the period of the schedule, with all values latched coincident with writing the upper 32 bits of the seconds field.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x30  Sch period (fractional ns)      RW -
        --------  ------------------------------  -------------
        RBB+0x34  Sch period (ns)                 RW -
        --------  ------------------------------  -------------
        RBB+0x38  Sch period (sec, lower 32)      RW -
        --------  ------------------------------  -------------
        RBB+0x3C  Sch period (sec, upper 32)      RW -
        ========  ==============================  =============

.. object:: Timeslot period

    The timeslot period registers control the period of each time slot, with all values latched coincident with writing the upper 32 bits of the seconds field.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x40  TS period (fractional ns)       RW -
        --------  ------------------------------  -------------
        RBB+0x44  TS period (ns)                  RW -
        --------  ------------------------------  -------------
        RBB+0x48  TS period (sec, lower 32)       RW -
        --------  ------------------------------  -------------
        RBB+0x4C  TS period (sec, upper 32)       RW -
        ========  ==============================  =============

.. object:: Active period

    The active period registers control the active period of each time slot, with all values latched coincident with writing the upper 32 bits of the seconds field.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x50  Active period (fractional ns)   RW -
        --------  ------------------------------  -------------
        RBB+0x54  Active period (ns)              RW -
        --------  ------------------------------  -------------
        RBB+0x58  Active period (sec, lower 32)   RW -
        --------  ------------------------------  -------------
        RBB+0x5C  Active period (sec, upper 32)   RW -
        ========  ==============================  =============

TDMA timing parameters
======================

The TDMA schedule is defined by several parameters - the schedule start time, schedule period, timeslot period, and timeslot active period.  This figure depicts the relationship between these parameters::

      schedule
       start
         |
         V
         |<-------- schedule period -------->|
    -----+--------+--------+--------+--------+--------+---
         | SLOT 0 | SLOT 1 | SLOT 2 | SLOT 3 | SLOT 0 | 
    -----+--------+--------+--------+--------+--------+---
         |<------>|
          timeslot
           period


         |<-------- timeslot period -------->|
    -----+-----------------------------------+------------
         | SLOT 0                            | SLOT 1   
    -----+-----------------------------------+------------
         |<---- active period ----->|

The schedule start time is the absolute start time.  Each subsequent schedule will start on a multiple of the schedule period after the start time.  Each schedule starts on timeslot 0, and advances to the next timeslot each timeslot period.  The timeslot active period is the active period for each timeslot, forming a guard period at the end of the timeslot.  It is recommended that the timeslot period divide evenly into the schedule period, but rounding errors will not accumulate as the schedule period takes precedence over the timeslot period.  Similarly, the timeslot period takes precedence over the timeslot active period.
