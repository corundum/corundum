.. _mod_mqnic_ptp_perout:

====================
``mqnic_ptp_perout``
====================

``mqnic_ptp_perout`` implements the PTP period output functionality.  It wraps ``ptp_perout`` and provides a register interface for control, see :ref:`rb_phc_perout`.

Parameters
==========

.. object:: REG_ADDR_WIDTH

    Register interface address width, default ``6``.

.. object:: REG_DATA_WIDTH

    Register interface data width, default ``32``.

.. object:: REG_STRB_WIDTH

    Register interface byte enable width, must be set to ``(REG_DATA_WIDTH/8)``.

.. object:: RB_BASE_ADDR

    Base address of control register block, default ``0``.

.. object:: RB_NEXT_PTR

    Address of next control register block, default ``0``.

Ports
=====

.. object:: clk

    Logic clock.

    .. table::

        ======  ===  =====  ==================
        Signal  Dir  Width  Description
        ======  ===  =====  ==================
        clk     in   1      Logic clock
        ======  ===  =====  ==================

.. object:: rst
    
    Logic reset, active high

    .. table::

        ======  ===  =====  ==================
        Signal  Dir  Width  Description
        ======  ===  =====  ==================
        rst     in   1      Logic reset, active high
        ======  ===  =====  ==================

.. object:: reg

    Control register interface

    .. table::

        ===========  ===  ===============  ===================
        Signal       Dir  Width            Description
        ===========  ===  ===============  ===================
        reg_wr_addr  in   REG_ADDR_WIDTH   Write address
        reg_wr_data  in   REG_DATA_WIDTH   Write data
        reg_wr_strb  in   REG_STRB_WIDTH   Write byte enable
        reg_wr_en    in   1                Write enable
        reg_wr_wait  out  1                Write wait
        reg_wr_ack   out  1                Write acknowledge
        reg_rd_addr  in   REG_ADDR_WIDTH   Read address
        reg_rd_en    in   1                Read enable
        reg_rd_data  out  REG_DATA_WIDTH   Read data
        reg_rd_wait  out  1                Read wait
        reg_rd_ack   out  1                Read acknowledge
        ===========  ===  ===============  ===================

.. object:: ptp

    PTP signals

    .. table::

        =================  ===  =====  ===================
        Signal             Dir  Width  Description
        =================  ===  =====  ===================
        ptp_ts_96          in   96     PTP timestamp
        ptp_ts_step        in   1      PTP timestamp step
        ptp_perout_locked  out  1      Period output locked
        ptp_perout_error   out  1      Period output error
        ptp_perout_pulse   out  1      Period output pulse
        =================  ===  =====  ===================
