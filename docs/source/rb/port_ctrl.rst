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
    RBB+0x10  TX control     TX control/status               RW 0x00000000
    --------  -------------  ------------------------------  -------------
    RBB+0x14  RX control     RX control/status               RW 0x00000000
    --------  -------------  ------------------------------  -------------
    RBB+0x18  FC ctrl        RX quanta step  TX quanta step  RW -
    --------  -------------  --------------  --------------  -------------
    RBB+0x1C  LFC ctrl       ctrl    LFC watermark           RW 0x00000000
    --------  -------------  ------  ----------------------  -------------
    RBB+0x20  PFC ctrl 0     ctrl    PFC watermark 0         RW 0x00000000
    --------  -------------  ------  ----------------------  -------------
    RBB+0x24  PFC ctrl 1     ctrl    PFC watermark 1         RW 0x00000000
    --------  -------------  ------  ----------------------  -------------
    RBB+0x28  PFC ctrl 2     ctrl    PFC watermark 2         RW 0x00000000
    --------  -------------  ------  ----------------------  -------------
    RBB+0x2C  PFC ctrl 3     ctrl    PFC watermark 3         RW 0x00000000
    --------  -------------  ------  ----------------------  -------------
    RBB+0x30  PFC ctrl 4     ctrl    PFC watermark 4         RW 0x00000000
    --------  -------------  ------  ----------------------  -------------
    RBB+0x34  PFC ctrl 5     ctrl    PFC watermark 5         RW 0x00000000
    --------  -------------  ------  ----------------------  -------------
    RBB+0x38  PFC ctrl 6     ctrl    PFC watermark 6         RW 0x00000000
    --------  -------------  ------  ----------------------  -------------
    RBB+0x3C  PFC ctrl 7     ctrl    PFC watermark 7         RW 0x00000000
    ========  =============  ======  ======================  =============

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
        0    LFC (IEEE 802.3 annex 31B)
        1    PFC (IEEE 802.3 annex 31D)
        2    Internal MAC control
        ===  =======================

.. object:: TX control/status

    The TX control/status field contains some high-level control and status registers for the transmit side of the link associated with the port.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x10  TX control/status               RW 0x00000000
        ========  ==============================  =============

    Control bits:

    .. table::

        ===  =======================
        Bit  Function
        ===  =======================
        0    TX enable
        8    TX pause control (halt TX traffic)
        16   TX status (link is ready)
        17   TX reset status (MAC TX is in reset)
        24   TX pause req status
        25   TX pause ack status
        ===  =======================

.. object:: RX control/status

    The RX control/status field contains some high-level control and status registers for the receive side of the link associated with the port.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x14  RX control/status               RO -
        ========  ==============================  =============

    Status bits:

    .. table::

        ===  =======================
        Bit  Function
        ===  =======================
        0    RX enable
        8    RX pause control (halt RX traffic)
        16   RX status (link is ready)
        17   RX reset status (MAC RX is in reset)
        24   RX pause req status
        25   RX pause ack status
        ===  =======================

.. object:: FC control

    The FC control field contains the quanta step size per clock cycle in units of 1/256 of one quanta for the internal MAC control layer.  Default value is based on the MAC interface width.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x18  RX quanta step  TX quanta step  RW -
        ========  ==============  ==============  =============

.. object:: LFC control

    The LFC control field contains control and status registers for link-level flow control (LFC) (IEEE 802.3 annex 31B pause frames).

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x1C  ctrl    LFC watermark           RW 0x00000000
        ========  ======  ======================  =============

    control bits:

    .. table::

        ===  =======================
        Bit  Function
        ===  =======================
        24   TX LFC en
        25   RX LFC en
        28   TX LFC req
        29   RX LFC req
        ===  =======================

.. object:: PFC control N

    The PFC control field contains control and status registers for priority flow control (PFC) (IEEE 802.3 annex 31D PFC).

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x20  ctrl    PFC watermark           RW 0x00000000
        ========  ======  ======================  =============

    control bits:

    .. table::

        ===  =======================
        Bit  Function
        ===  =======================
        24   TX PFC en
        25   RX PFC en
        28   TX PFC req
        29   RX PFC req
        ===  =======================
