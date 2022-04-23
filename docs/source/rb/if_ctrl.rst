.. _rb_if_ctrl:

================================
Interface control register block
================================

The interface control register block has a header with type 0x0000C001, version 0x00000400, and contains several interface-level control registers.

.. table::

    ========  =============  ======  ======  ======  ======  =============
    Address   Field          31..24  23..16  15..8   7..0    Reset value
    ========  =============  ======  ======  ======  ======  =============
    RBB+0x00  Type           Vendor ID       Type            RO 0x0000C001
    --------  -------------  --------------  --------------  -------------
    RBB+0x04  Version        Major   Minor   Patch   Meta    RO 0x00000300
    --------  -------------  ------  ------  ------  ------  -------------
    RBB+0x08  Next pointer   Pointer to next register block  RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x0C  Features       Interface feature bits          RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x10  Port count     Port count                      RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x14  Sched count    Scheduler block count           RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x18  \-             \-                              RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x1C  \-             \-                              RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x20  Max TX MTU     Max TX MTU                      RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x24  Max RX MTU     Max RX MTU                      RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x28  TX MTU         TX MTU                          RW -
    --------  -------------  ------------------------------  -------------
    RBB+0x2C  RX MTU         RX MTU                          RW -
    ========  =============  ==============================  =============

See :ref:`rb_overview` for definitions of the standard register block header fields.

.. object:: Features

    The features field contains all of the interface-level feature bits, indicating the state of various optional features that can be enabled via Verilog parameters during synthesis.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x0C  Interface feature bits          RO -
        ========  ==============================  =============

    Currently implemented feature bits:

    .. table::

        ===  =======================
        Bit  Feature
        ===  =======================
        0    RSS
        4    PTP timestamping
        8    TX checksum offloading
        9    RX checksum offloading
        10   RX flow hash offloading
        ===  =======================

.. object:: Port count

    The port count field contains the number of ports associated with the interface, as configured via Verilog parameters during synthesis.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x10  Port count                      RO -
        ========  ==============================  =============

.. object:: Scheduler block count

    The scheduler block count field contains the number of scheduler blocks associated with the interface, as configured via Verilog parameters during synthesis.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x14  Scheduler block count           RO -
        ========  ==============================  =============

.. object:: Max TX MTU

    The max TX MTU field contains the maximum frame size on the transmit path, as configured via Verilog parameters during synthesis.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x20  Max TX MTU                      RO -
        ========  ==============================  =============

.. object:: Max RX MTU

    The max RX MTU field contains the maximum frame size on the receive path, as configured via Verilog parameters during synthesis.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x24  Max RX MTU                      RO -
        ========  ==============================  =============

.. object:: TX MTU

    The TX MTU field controls the maximum frame size on the transmit path.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x28  TX MTU                          RW -
        ========  ==============================  =============

.. object:: RX MTU

    The RX MTU field controls the maximum frame size on the receive path.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x2C  RX MTU                          RW -
        ========  ==============================  =============
