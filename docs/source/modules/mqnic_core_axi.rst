.. _mod_mqnic_core_axi:

==================
``mqnic_core_axi``
==================

``mqnic_core_axi`` is the core integration-level module for mqnic for the AXI host interface.  Wrapper around :ref:`mod_mqnic_core`, adding the AXI DMA interface module.

``mqnic_core_axi`` integrates the following modules:

* ``dma_if_axi``: AXI DMA engine
* :ref:`mod_mqnic_core`: core logic

Parameters
==========

Only parameters implemented in the wrapper are described here, for the other parameters see :ref:`mod_mqnic_core`.

.. object:: AXI_DATA_WIDTH

    AXI master interface data signal width, default ``128``.

.. object:: AXI_ADDR_WIDTH

    AXI master interface address signal width, default ``32``.

.. object:: AXI_STRB_WIDTH

    AXI master interface byte enable signal width, default ``(AXI_DATA_WIDTH/8)``.

.. object:: AXI_ID_WIDTH

    AXI master interface ID signal width, default ``8``.

.. object:: AXI_DMA_MAX_BURST_LEN

    AXI DMA maximum burst length, default ``256``.

.. object:: AXI_DMA_READ_USE_ID

    Use ID field for AXI DMA reads, default ``0``.

.. object:: AXI_DMA_WRITE_USE_ID

    Use ID field for AXI DMA writes, default ``1``.

.. object:: AXI_DMA_READ_OP_TABLE_SIZE

    AXI read DMA operation table size, default ``2**(AXI_ID_WIDTH)``.

.. object:: AXI_DMA_WRITE_OP_TABLE_SIZE

    AXI write DMA operation table size, default ``2**(AXI_ID_WIDTH)``.

.. object:: IRQ_COUNT

    IRQ channel count, default ``32``.

.. object:: STAT_DMA_ENABLE

    Enable DMA-related statistics, default ``1``.

.. object:: STAT_AXI_ENABLE

    Enable AXI-related statistics, default ``1``.

Ports
=====

Only ports implemented in the wrapper are described here, for the other ports see :ref:`mod_mqnic_core`.

.. object:: m_axi

    AXI master interface (DMA).

    .. table::

        =============  ===  ==============  ===================
        Signal         Dir  Width           Description
        =============  ===  ==============  ===================
        m_axi_awid     out  AXI_ID_WIDTH    Write ID
        m_axi_awaddr   out  AXI_ADDR_WIDTH  Write address
        m_axi_awlen    out  8               Write burst length
        m_axi_awsize   out  3               Write burst size
        m_axi_awburst  out  2               Write burst type
        m_axi_awlock   out  1               Write lock
        m_axi_awcache  out  4               Write cache
        m_axi_awprot   out  3               Write protect
        m_axi_awvalid  out  1               Write valid
        m_axi_awready  in   1               Write ready
        m_axi_wdata    out  AXI_DATA_WIDTH  Write data data
        m_axi_wstrb    out  AXI_STRB_WIDTH  Write data strobe
        m_axi_wlast    out  1               Write data last
        m_axi_wvalid   out  1               Write data valid
        m_axi_wready   in   1               Write data ready
        m_axi_bid      in   AXI_ID_WIDTH    Write response ID
        m_axi_bresp    in   2               Write response status
        m_axi_bvalid   in   1               Write response valid
        m_axi_bready   out  1               Write response ready
        m_axi_arid     out  AXI_ID_WIDTH    Read ID
        m_axi_araddr   out  AXI_ADDR_WIDTH  Read address
        m_axi_arlen    out  8               Read burst length
        m_axi_arsize   out  3               Read burst size
        m_axi_arburst  out  2               Read burst type
        m_axi_arlock   out  1               Read lock
        m_axi_arcache  out  4               Read cache
        m_axi_arprot   out  3               Read protect
        m_axi_arvalid  out  1               Read address valid
        m_axi_arready  in   1               Read address ready
        m_axi_rid      in   AXI_ID_WIDTH    Read response ID
        m_axi_rdata    in   AXI_DATA_WIDTH  Read response data
        m_axi_rresp    in   2               Read response status
        m_axi_rlast    in   1               Read response last
        m_axi_rvalid   in   1               Read response valid
        m_axi_rready   out  1               Read response ready
        =============  ===  ==============  ===================

.. object:: msi_irq

    Interrupt outputs

    .. table::

        ======  ===  =========  ===================
        Signal  Dir  Width      Description
        ======  ===  =========  ===================
        irq     out  IRQ_COUNT  Interrupt request
        ======  ===  =========  ===================
