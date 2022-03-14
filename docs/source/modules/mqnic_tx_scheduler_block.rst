.. _mod_mqnic_tx_scheduler_block:

============================
``mqnic_tx_scheduler_block``
============================

``mqnic_tx_scheduler_block`` is the top-level block for the transmit scheduler.  It is instantiated in :ref:`mod_mqnic_interface`.  This is a pluggable module, intended to be replaced by a customized implementation via the build system.  See .... for more details.

Two variations are provided:

* ``mqnic_tx_scheduler_block_rr``: round-robin transmit scheduler (:ref:`mod_tx_scheduler_rr`)
* ``mqnic_tx_scheduler_block_rr_tdma``: round-robin transmit scheduler (:ref:`mod_tx_scheduler_rr`) with TDMA scheduler controller

Parameters
==========

.. object:: PORTS

    Number of ports, default ``1``.

.. object:: INDEX

    Scheduler index, default ``0``.

.. object:: REG_ADDR_WIDTH

    Width of control register interface address in bits, default ``16``.

.. object:: REG_DATA_WIDTH

    Width of control register interface data in bits, default ``32``.

.. object:: REG_STRB_WIDTH

    Width of control register interface strb, must be set to ``(REG_DATA_WIDTH/8)``.

.. object:: RB_BASE_ADDR

    Register block base address, default ``0``.

.. object:: RB_NEXT_PTR

    Register block next pointer, default ``0``.

.. object:: AXIL_DATA_WIDTH

    Width of AXI lite data bus in bits, default ``32``.

.. object:: AXIL_ADDR_WIDTH

    Width of AXI lite address bus in bits, default ``16``.

.. object:: AXIL_STRB_WIDTH

    Width of AXI lite wstrb (width of data bus in words), must be set to ``AXIL_DATA_WIDTH/8``.

.. object:: AXIL_OFFSET

    Offset to AXI lite interface, default ``0``.

.. object:: LEN_WIDTH

    Length field width, default ``16``.

.. object:: REQ_TAG_WIDTH

    Transmit request tag field width, default ``8``.

.. object:: OP_TABLE_SIZE

    Number of outstanding operations, default ``16``.

.. object:: QUEUE_INDEX_WIDTH

    Queue index width, default ``6``.

.. object:: PIPELINE

    Pipeline setting, default ``3``.

.. object:: TDMA_INDEX_WIDTH

    Scheduler TDMA index width, default ``8``.

.. object:: PTP_TS_WIDTH

    PTP timestamp width, default ``96``.

.. object:: AXIS_TX_DEST_WIDTH

    AXI stream tdest signal width, default ``$clog2(PORTS)+4``.

.. object:: MAX_TX_SIZE

    Max transmit packet size, default ``2048``.

Ports
=====

.. object:: clk

    Logic clock.  Most interfaces are synchronous to this clock.

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

.. object:: ctrl_reg

    Control register interface

    .. table::

        ================  ===  ===============  ===================
        Signal            Dir  Width            Description
        ================  ===  ===============  ===================
        ctrl_reg_wr_addr  in   REG_ADDR_WIDTH   Write address
        ctrl_reg_wr_data  in   REG_DATA_WIDTH   Write data
        ctrl_reg_wr_strb  in   REG_STRB_WIDTH   Write byte enable
        ctrl_reg_wr_en    in   1                Write enable
        ctrl_reg_wr_wait  out  1                Write wait
        ctrl_reg_wr_ack   out  1                Write acknowledge
        ctrl_reg_rd_addr  in   REG_ADDR_WIDTH   Read address
        ctrl_reg_rd_en    in   1                Read enable
        ctrl_reg_rd_data  out  REG_DATA_WIDTH   Read data
        ctrl_reg_rd_wait  out  1                Read wait
        ctrl_reg_rd_ack   out  1                Read acknowledge
        ================  ===  ===============  ===================

.. object:: s_axil

    AXI-Lite slave interface.  This interface provides access to memory-mapped per-queue control registers.

    .. table::

        ==============  ===  ===============  ===================
        Signal          Dir  Width            Description
        ==============  ===  ===============  ===================
        s_axil_awaddr   in   AXIL_ADDR_WIDTH  Write address
        s_axil_awprot   in   3                Write protect
        s_axil_awvalid  in   1                Write address valid
        s_axil_awready  out  1                Write address ready
        s_axil_wdata    in   AXIL_DATA_WIDTH  Write data
        s_axil_wstrb    in   AXIL_STRB_WIDTH  Write data strobe
        s_axil_wvalid   in   1                Write data valid
        s_axil_wready   out  1                Write data ready
        s_axil_bresp    out  2                Write response status
        s_axil_bvalid   out  1                Write response valid
        s_axil_bready   in   1                Write response ready
        s_axil_araddr   in   AXIL_ADDR_WIDTH  Read address
        s_axil_arprot   in   3                Read protect
        s_axil_arvalid  in   1                Read address valid
        s_axil_arready  out  1                Read address ready
        s_axil_rdata    out  AXIL_DATA_WIDTH  Read response data
        s_axil_rresp    out  2                Read response status
        s_axil_rvalid   out  1                Read response valid
        s_axil_rready   in   1                Read response ready
        ==============  ===  ===============  ===================

.. object:: m_axis_tx_req

    Transmit request output, for transmit requests to the transmit engine.

    .. table::

        ===================  ===  ==================  ===================
        Signal               Dir  Width               Description
        ===================  ===  ==================  ===================
        m_axis_tx_req_queue  out  QUEUE_INDEX_WIDTH   Queue index
        m_axis_tx_req_tag    out  REQ_TAG_WIDTH       Tag
        m_axis_tx_req_dest   out  AXIS_TX_DEST_WIDTH  Destination port and TC
        m_axis_tx_req_valid  out  1                   Valid
        m_axis_tx_req_ready  in   1                   Ready
        ===================  ===  ==================  ===================

.. object:: s_axis_tx_req_status

    Transmit request status input, for responses from the transmit engine.

    .. table::

        ==========================  ===  =============  ===================
        Signal                      Dir  Width          Description
        ==========================  ===  =============  ===================
        s_axis_tx_req_status_len    in   LEN_WIDTH      Packet length
        s_axis_tx_req_status_tag    in   REQ_TAG_WIDTH  Tag
        s_axis_tx_req_status_valid  in   1              Valid
        ==========================  ===  =============  ===================

.. object:: s_axis_doorbell

    Doorbell input, for enqueue notifications from the transmit queue manager.

    .. table::

        =====================  ===  =================  ===================
        Signal                 Dir  Width              Description
        =====================  ===  =================  ===================
        s_axis_doorbell_queue  in   QUEUE_INDEX_WIDTH  Queue index
        s_axis_doorbell_valid  in   1                  Valid
        =====================  ===  =================  ===================

.. object:: ptp_ts

    PTP time input from PTP clock

    .. table::

        ===========  ===  ============  ===================
        Signal       Dir  Width         Description
        ===========  ===  ============  ===================
        ptp_ts_96    in   PTP_TS_WIDTH  PTP time
        ptp_ts_step  in   1             PTP clock step
        ===========  ===  ============  ===================

.. object:: config

    Configuration signals

    .. table::

        ===========  ===  ============  ===================
        Signal       Dir  Width         Description
        ===========  ===  ============  ===================
        mtu          in   LEN_WIDTH     MTU
        ===========  ===  ============  ===================
