.. _rb_port_ctrl:

===========================
Port control register block
===========================

The port control register block has a header with type 0x0000C003, version 0x00000200, and contains several port-level control registers.

.. table::

    ========  =============  ======  ======  ======  ======  =============
    Address   Field          31..24  23..16  15..8   7..0    Reset value
    ========  =============  ======  ======  ======  ======  =============
    RBB+0x00  Type           Vendor ID       Type            RO 0x0000C003
    --------  -------------  --------------  --------------  -------------
    RBB+0x04  Version        Major   Minor   Patch   Meta    RO 0x00000200
    --------  -------------  ------  ------  ------  ------  -------------
    RBB+0x08  Next pointer   Pointer to next register block  RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x0C  Features       Port feature bits               RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x10  TX status      TX status                       RO -
    --------  -------------  ------------------------------  -------------
    RBB+0x14  RX status      RX status                       RO -
    ========  =============  ==============================  =============

See :ref:`rb_overview` for definitions of the standard register block header fields.

.. object:: Features

    The features field contains all of the port-level feature bits, indicating the state of various optional features that can be enabled via Verilog parameters during synthesis.

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
        \-   None implemented
        ===  =======================

.. object:: TX status

    The TX status field contains some high-level status information about the transmit size of the link associated with the port.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x10  TX status                       RO -
        ========  ==============================  =============

    Status bits:

    .. table::

        ===  =======================
        Bit  Function
        ===  =======================
        0    TX status (link is ready)
        1    TX reset status (MAC TX is in reset)
        ===  =======================

.. object:: RX status

    The RX status field contains some high-level status information about the receive side of the link associated with the port.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x14  RX status                       RO -
        ========  ==============================  =============

    Status bits:

    .. table::

        ===  =======================
        Bit  Function
        ===  =======================
        0    RX status (link is ready)
        1    RX reset status (MAC RX is in reset)
        ===  =======================
