.. _mod_mqnic_ptp:

=============
``mqnic_ptp``
=============

``mqnic_ptp`` implements the PTP subsystem, including PTP clock and period output modules.

``mqnic_ptp`` integrates the following modules:

* :ref:`mod_mqnic_ptp_clock`: PTP clock (:ref:`rb_phc`)
* :ref:`mod_mqnic_ptp_perout`: PTP period output (:ref:`rb_phc_perout`)

Parameters
==========

.. object:: PTP_PERIOD_NS_WIDTH

    PTP period ns field width, default ``4``.

.. object:: PTP_OFFSET_NS_WIDTH

    PTP offset ns field width, default ``32``.

.. object:: PTP_FNS_WIDTH

    PTP fractional ns field width, default ``32``.

.. object:: PTP_PERIOD_NS

    PTP nominal period, ns portion ``4'd4``.

.. object:: PTP_PERIOD_FNS

    PTP nominal period, fractional ns portion ``32'd0``.

.. object:: PTP_PEROUT_ENABLE

    Enable PTP period output module, default ``0``.

.. object:: PTP_PEROUT_COUNT

    Number of PTP period output channels, default ``1``.

.. object:: REG_ADDR_WIDTH

    Register interface address width, default ``7+(PTP_PEROUT_ENABLE ? $clog2((PTP_PEROUT_COUNT+1)/2) + 1 : 0)``.

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

        =================  ===  ================  ===================
        Signal             Dir  Width             Description
        =================  ===  ================  ===================
        ptp_pps            out  1                 Pulse-per-second
        ptp_ts_96          out  96                PTP timestamp
        ptp_ts_step        out  1                 PTP timestamp step
        ptp_perout_locked  out  PTP_PEROUT_COUNT  Period output channel locked
        ptp_perout_error   out  PTP_PEROUT_COUNT  Period output channel error
        ptp_perout_pulse   out  PTP_PEROUT_COUNT  Period output channel pulse
        =================  ===  ================  ===================
