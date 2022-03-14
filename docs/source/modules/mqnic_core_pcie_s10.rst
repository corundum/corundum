.. _mod_mqnic_core_pcie_s10:

=======================
``mqnic_core_pcie_s10``
=======================

``mqnic_core_pcie_s10`` is the core integration-level module for mqnic for the PCIe host interface on Intel Stratix 10 GX, SX, MX, and TX series devices with H-tiles or L-tiles.  Wrapper around :ref:`mod_mqnic_core_pcie`, adding device-specific shims for the PCIe interface.

``mqnic_core_pcie_s10`` integrates the following modules:

* ``pcie_s10_if``: PCIe interface shim
* :ref:`mod_mqnic_core_pcie`: core logic for PCI express

Parameters
==========

Only parameters implemented in the wrapper are described here, for the other parameters see :ref:`mod_mqnic_core_pcie`.

.. object:: SEG_COUNT

    TLP segment count, default ``1``.

.. object:: SEG_DATA_WIDTH

    TLP segment data signal width, default ``256``.

.. object:: SEG_EMPTY_WIDTH

    TLP segment empty signal width, must be set to ``$clog2(SEG_DATA_WIDTH/32)``.

.. object:: TX_SEQ_NUM_WIDTH

    Transmit sequence number width, default ``6``.

.. object:: TX_SEQ_NUM_ENABLE

    Transmit sequence number enable, default ``1``.

.. object:: L_TILE

    Tile select, ``0`` for H-tile, ``1`` for L-tile, default ``0``.

Ports
=====

Only ports implemented in the wrapper are described here, for the other ports see :ref:`mod_mqnic_core_pcie`.

.. object:: rx_st

    H-Tile/L-Tile RX AVST interface

    .. table::

        ===============  ===  =========================  ===================
        Signal           Dir  Width                      Description
        ===============  ===  =========================  ===================
        rx_st_data       in   SEG_COUNT*SEG_DATA_WIDTH   TLP data
        rx_st_empty      in   SEG_COUNT*SEG_EMPTY_WIDTH  Empty
        rx_st_sop        in   SEG_COUNT                  Start of packet
        rx_st_eop        in   SEG_COUNT                  End of packet
        rx_st_valid      in   SEG_COUNT                  Valid
        rx_st_ready      out  1                          Ready
        rx_st_vf_active  in   SEG_COUNT                  VF active
        rx_st_func_num   in   SEG_COUNT*2                Function number
        rx_st_vf_num     in   SEG_COUNT*11               VF number
        rx_st_bar_range  in   SEG_COUNT*3                BAR range
        ===============  ===  =========================  ===================

.. object:: tx_st

    H-Tile/L-Tile TX AVST interface

    .. table::

        ===========  ===  ========================  ===================
        Signal       Dir  Width                     Description
        ===========  ===  ========================  ===================
        tx_st_data   out  SEG_COUNT*SEG_DATA_WIDTH  TLP data
        tx_st_sop    out  SEG_COUNT                 Start of packet
        tx_st_eop    out  SEG_COUNT                 End of packet
        tx_st_valid  out  SEG_COUNT                 Valid
        tx_st_ready  in   1                         Ready
        tx_st_err    out  SEG_COUNT                 Error
        ===========  ===  ========================  ===================

.. object:: tx_fc

    H-Tile/L-Tile TX flow control

    .. table::

        =====================  ===  ===========  ===================
        Signal                 Dir  Width        Description
        =====================  ===  ===========  ===================
        tx_ph_cdts             in   8            Posted header credits
        tx_pd_cdts             in   12           Posted data credits
        tx_nph_cdts            in   8            Non-posted header credits
        tx_npd_cdts            in   12           Non-posted data credits
        tx_cplh_cdts           in   8            Completion header credits
        tx_cpld_cdts           in   12           Completion data credits
        tx_hdr_cdts_consumed   in   SEG_COUNT    Header credits consumed
        tx_data_cdts_consumed  in   SEG_COUNT    Data credits consumed
        tx_cdts_type           in   SEG_COUNT*2  Credit type
        tx_cdts_data_value     in   SEG_COUNT*1  Credit data value
        =====================  ===  ===========  ===================

.. object:: app_msi

    H-Tile/L-Tile MSI interrupt interface

    .. table::

        ================  ===  =====  ===================
        Signal            Dir  Width  Description
        ================  ===  =====  ===================
        app_msi_req       out  1      MSI request
        app_msi_ack       in   1      MSI acknowledge
        app_msi_tc        out  3      MSI traffic class
        app_msi_num       out  5      MSI number
        app_msi_func_num  out  2      Function number
        ================  ===  =====  ===================

.. object:: tl_cfg

    H-Tile/L-Tile configuration interface

    .. table::

        ===========  ===  =====  ===================
        Signal       Dir  Width  Description
        ===========  ===  =====  ===================
        tl_cfg_ctl   in   32     Config data
        tl_cfg_add   in   5      Config address
        tl_cfg_func  in   2      Config function
        ===========  ===  =====  ===================
