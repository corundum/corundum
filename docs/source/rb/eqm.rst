.. _rb_eqm:

==================================
Event queue manager register block
==================================

The event queue manager register block has a header with type 0x0000C010, version 0x00000300, and indicates the location of the event queue manager registers and number of event queues.

.. table::

    ========  =============  ======  ======  ======  ======  =============
    Address   Field          31..24  23..16  15..8   7..0    Reset value
    ========  =============  ======  ======  ======  ======  =============
    RBB+0x00  Type           Vendor ID       Type            RO 0x0000C010
    --------  -------------  --------------  --------------  -------------
    RBB+0x04  Version        Major   Minor   Patch   Meta    RO 0x00000400
    --------  -------------  ------  ------  ------  ------  -------------
    RBB+0x08  Next pointer   Pointer to next register block  RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x0C  Offset         Offset to queue manager         RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x10  Count          Queue count                     RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x14  Stride         Queue control register stride   RO 0x00000010
    ========  =============  ==============================  =============

See :ref:`rb_overview` for definitions of the standard register block header fields.

.. object:: Offset

    The offset field contains the offset to the start of the event queue manager region, relative to the start of the current region.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x0C  Offset to queue manager         RO -
        ========  ==============================  =============

.. object:: Count

    The count field contains the number of queues.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x10  Queue count                     RO -
        ========  ==============================  =============

.. object:: Stride

    The stride field contains the size of the control registers associated with each queue.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x14  Queue control register stride   RO 0x00000010
        ========  ==============================  =============

Event queue manager CSRs
========================

Each queue has several associated control registers, detailed in this table:

.. table::

    =========  ==============  ======  ======  ======  ======  =============
    Address    Field           31..24  23..16  15..8   7..0    Reset value
    =========  ==============  ======  ======  ======  ======  =============
    Base+0x00  Base addr L     Ring base addr (lower), VF      RW -
    ---------  --------------  ------------------------------  -------------
    Base+0x04  Base addr H     Ring base addr (upper)          RW -
    ---------  --------------  ------------------------------  -------------
    Base+0x08  Control/status  Control/status  IRQN            RO -
    ---------  --------------  --------------  --------------  -------------
    Base+0x0C  Pointers        Cons pointer    Prod pointer    RO -
    =========  ==============  ==============  ==============  =============

.. object:: Base address

    The base address field contains the base address of the ring buffer as well as the VF ID.  The base address must be aligned to a 4096 byte boundary and sits in bits 63:12, leaving room for the VF ID in bits 11:0.  The base address is read-only when the queue is enabled.  The VF ID field is read-only; use the set VF ID command to change the VF ID.

    .. table::

        =========  ======  ======  ======  ======  =============
        Address    31..24  23..16  15..8   7..0    Reset value
        =========  ======  ======  ======  ======  =============
        Base+0x00  Ring base addr (lower), VF      RW -
        ---------  ------------------------------  -------------
        Base+0x04  Ring base addr (upper)          RW -
        =========  ==============================  =============

.. object:: Control/status

    The control/status field contains control and status information for the queue, and the IRQN field contains the corresponding IRQ number.  All fields are read-only; use commands to set the size and IRQN and to enable/disable and arm/disarm the queue.

    .. table::

        =========  ======  ======  ======  ======  =============
        Address    31..24  23..16  15..8   7..0    Reset value
        =========  ======  ======  ======  ======  =============
        Base+0x08  Control/status  IRQN            RO -
        =========  ==============  ==============  =============

    Control/status bit definitions

    .. table::

        =====  =========
        Bit    Function
        =====  =========
        0      Enable
        1      Arm
        3      Active
        15:12  Log size
        =====  =========

.. object:: Pointers

    The pointers field contains the queue producer and consumer pointers.  Bits 15:0 are the producer pointer, while bits 31:16 are the consumer pointer.  Both fields are read-only; use the set prod and cons pointer commands to update the pointers.

    .. table::

        =========  ======  ======  ======  ======  =============
        Address    31..24  23..16  15..8   7..0    Reset value
        =========  ======  ======  ======  ======  =============
        Base+0x0C  Cons pointer    Prod pointer    RO -
        =========  ==============  ==============  =============

Event queue manager commands
============================

.. table::

    ========================  ======  ======  ======  ======
    Command                   31..24  23..16  15..8   7..0
    ========================  ======  ======  ======  ======
    Set VF ID                 0x8001          VF ID
    ------------------------  --------------  --------------
    Set size                  0x8002          Log size
    ------------------------  --------------  --------------
    Set IRQN                  0xC0    IRQN
    ------------------------  ------  ----------------------
    Set prod pointer          0x8080          Prod pointer
    ------------------------  --------------  --------------
    Set cons pointer          0x8090          Cons pointer
    ------------------------  --------------  --------------
    Set cons pointer, arm     0x8091          Cons pointer
    ------------------------  --------------  --------------
    Set enable                0x400001                Enable
    ------------------------  ----------------------  ------
    Set arm                   0x400002                Arm
    ========================  ======================  ======

.. object:: Set VF ID

    The set VF ID command is used to set the VF ID for the queue.  Allowed when queue is disabled and inactive.

    .. table::

        ======  ======  ======  ======
        31..24  23..16  15..8   7..0
        ======  ======  ======  ======
        0x8001          VF ID
        ==============  ==============

.. object:: Set size

    The set size command is used to set the size of the ring buffer as the log base 2 of the number of elements.  Allowed when queue is disabled and inactive.

    .. table::

        ======  ======  ======  ======
        31..24  23..16  15..8   7..0
        ======  ======  ======  ======
        0x8002          Log size
        ==============  ==============

.. object:: Set IRQN

    The set IRQN command is used to set the IRQ number for interrupts generated by the queue.  Allowed when queue is disabled and inactive.

    .. table::

        ======  ======  ======  ======
        31..24  23..16  15..8   7..0
        ======  ======  ======  ======
        0xC0    IRQN
        ======  ======================

.. object:: Set prod pointer

    The set producer pointer command is used to set the queue producer pointer.  Allowed when queue is disabled and inactive.

    .. table::

        ======  ======  ======  ======
        31..24  23..16  15..8   7..0
        ======  ======  ======  ======
        0x8080          Prod pointer
        ==============  ==============

.. object:: Set cons pointer

    The set consumer pointer command is used to set the queue consumer pointer.  Allowed at any time.

    .. table::

        ======  ======  ======  ======
        31..24  23..16  15..8   7..0
        ======  ======  ======  ======
        0x8090          Cons pointer
        ==============  ==============

.. object:: Set cons pointer, arm

    The set consumer pointer, arm command is used to set the queue consumer pointer and simultaneously re-arm the queue.  Allowed at any time.

    .. table::

        ======  ======  ======  ======
        31..24  23..16  15..8   7..0
        ======  ======  ======  ======
        0x8091          Cons pointer
        ==============  ==============

.. object:: Set enable

    The set enable command is used to enable or disable the queue.  Allowed at any time.

    .. table::

        ======  ======  ======  ======
        31..24  23..16  15..8   7..0
        ======  ======  ======  ======
        0x400001                Enable
        ======================  ======

.. object:: Set arm

    The set arm command is used to arm or disarm the queue.  Allowed at any time.

    .. table::

        ======  ======  ======  ======
        31..24  23..16  15..8   7..0
        ======  ======  ======  ======
        0x400002                Arm
        ======================  ======
