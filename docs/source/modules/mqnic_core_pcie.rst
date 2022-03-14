.. _mod_mqnic_core_pcie:

===================
``mqnic_core_pcie``
===================

``mqnic_core_pcie`` is the core integration-level module for mqnic for the PCIe host interface.  Wrapper around :ref:`mod_mqnic_core`, adding PCIe DMA interface module and PCIe-AXI Lite masters for the NIC and application control BARs.

This module implements a generic PCIe host interface, which must be adapted to the target device with a wrapper.  The available wrappers are:

* :ref:`mod_mqnic_core_pcie_us` for Xilinx Virtex 7, UltraScale, and UltraScale+
* :ref:`mod_mqnic_core_pcie_s10` for Intel Stratix 10 H-tile/L-tile

``mqnic_core_pcie`` integrates the following modules:

* ``dma_if_pcie``: PCIe DMA engine
* ``pcie_axil_master``: AXI lite master module for control registers
* ``stats_pcie_if``: statistics collection for PCIe TLP traffic
* ``stats_dma_if_pcie``: statistics collection for PCIe DMA engine
* :ref:`mod_mqnic_core`: core logic

Parameters
==========

Only parameters implemented in the wrapper are described here, for the other parameters see :ref:`mod_mqnic_core`.

.. object:: TLP_SEG_COUNT

    Number of segments in the TLP interfaces, default ``1``.

.. object:: TLP_SEG_DATA_WIDTH

    TLP segment data width, default ``256``.

.. object:: TLP_SEG_STRB_WIDTH

    TLP segment byte enable width, must be set to ``TLP_SEG_DATA_WIDTH/32``.

.. object:: TLP_SEG_HDR_WIDTH

    TLP segment header width, must be ``128``.

.. object:: TX_SEQ_NUM_COUNT

    Number of transmit sequence number inputs, default ``1``.

.. object:: TX_SEQ_NUM_WIDTH

    Transmit sequence number width, default ``5``.

.. object:: TX_SEQ_NUM_ENABLE

    Use transmit sequence numbers, default ``0``.

.. object:: PF_COUNT

    PCIe PF count, default ``1``.

.. object:: VF_COUNT

    PCIe VF count, default ``0``.

.. object:: F_COUNT

    PCIe function count, must be ``PF_COUNT+VF_COUNT``.

.. object:: PCIE_TAG_COUNT

    PCIe tag count, default ``256``.

.. object:: PCIE_DMA_READ_OP_TABLE_SIZE

    PCIe read DMA operation table size, default ``PCIE_TAG_COUNT``.

.. object:: PCIE_DMA_READ_TX_LIMIT

    PCIe read DMA transmit operation limit, default ``2**TX_SEQ_NUM_WIDTH``.

.. object:: PCIE_DMA_READ_TX_FC_ENABLE

    Use transmit flow control credits in PCIe read DMA, default ``0``.

.. object:: PCIE_DMA_WRITE_OP_TABLE_SIZE

    PCIe write DMA operation table size, default ``2**TX_SEQ_NUM_WIDTH``.

.. object:: PCIE_DMA_WRITE_TX_LIMIT

    PCIe write DMA transmit operation limit, default ``2**TX_SEQ_NUM_WIDTH``.

.. object:: PCIE_DMA_WRITE_TX_FC_ENABLE

    Use transmit flow control credits in PCIe write DMA, default ``0``.

.. object:: TLP_FORCE_64_BIT_ADDR

    Force 64 bit address field for all TLPs, default ``0``.

.. object:: CHECK_BUS_NUMBER

    Check bus number in received TLPs, default ``1``.

.. object:: MSI_COUNT

    Number of MSI channels, default ``32``.

.. object:: STAT_DMA_ENABLE

    Enable DMA-related statistics, default ``1``.

.. object:: STAT_PCIE_ENABLE

    Enable PCIe-related statistics, default ``1``.

Ports
=====

Only ports implemented in the wrapper are described here, for the other ports see :ref:`mod_mqnic_core`.

.. object:: pcie_rx_req_tlp

    TLP input (request to BAR)

    .. table::

        ========================  ===  ================================  ===================
        Signal                    Dir  Width                             Description
        ========================  ===  ================================  ===================
        pcie_rx_req_tlp_data      in   TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH  TLP payload
        pcie_rx_req_tlp_hdr       in   TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH   TLP header
        pcie_rx_req_tlp_bar_id    in   TLP_SEG_COUNT*3                   BAR ID
        pcie_rx_req_tlp_func_num  in   TLP_SEG_COUNT*8                   Function
        pcie_rx_req_tlp_valid     in   TLP_SEG_COUNT                     Valid
        pcie_rx_req_tlp_sop       in   TLP_SEG_COUNT                     Start of packet
        pcie_rx_req_tlp_eop       in   TLP_SEG_COUNT                     End of packet
        pcie_rx_req_tlp_ready     out  1                                 Ready
        ========================  ===  ================================  ===================

.. object:: pcie_rx_cpl_tlp

    TLP input (completion to DMA)

    .. table::

        =====================  ===  ================================  ===================
        Signal                 Dir  Width                             Description
        =====================  ===  ================================  ===================
        pcie_rx_cpl_tlp_data   in   TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH  TLP payload
        pcie_rx_cpl_tlp_hdr    in   TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH   TLP header
        pcie_rx_cpl_tlp_error  in   TLP_SEG_COUNT*4                   Error
        pcie_rx_cpl_tlp_valid  in   TLP_SEG_COUNT                     Valid
        pcie_rx_cpl_tlp_sop    in   TLP_SEG_COUNT                     Start of packet
        pcie_rx_cpl_tlp_eop    in   TLP_SEG_COUNT                     End of packet
        pcie_rx_cpl_tlp_ready  out  1                                 Ready
        =====================  ===  ================================  ===================

.. object:: pcie_tx_rd_req_tlp

    TLP output (read request from DMA)

    .. table::

        ========================  ===  ===============================  ===================
        Signal                    Dir  Width                            Description
        ========================  ===  ===============================  ===================
        pcie_tx_rd_req_tlp_hdr    out  TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH  TLP header
        pcie_tx_rd_req_tlp_seq    out  TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH   TX seq num
        pcie_tx_rd_req_tlp_valid  out  TLP_SEG_COUNT                    Valid
        pcie_tx_rd_req_tlp_sop    out  TLP_SEG_COUNT                    Start of packet
        pcie_tx_rd_req_tlp_eop    out  TLP_SEG_COUNT                    End of packet
        pcie_tx_rd_req_tlp_ready  in   1                                Ready
        ========================  ===  ===============================  ===================

.. object:: s_axis_pcie_rd_req_tx_seq_num

    Transmit sequence number input (DMA read request)

    .. table::

        ===================================  ===  =================================  ===================
        Signal                               Dir  Width                              Description
        ===================================  ===  =================================  ===================
        s_axis_pcie_rd_req_tx_seq_num        in   TX_SEQ_NUM_COUNT*TX_SEQ_NUM_WIDTH  TX seq num
        s_axis_pcie_rd_req_tx_seq_num_valid  in   TX_SEQ_NUM_COUNT                   Valid
        ===================================  ===  =================================  ===================

.. object:: pcie_tx_wr_req_tlp

    TLP output (read request from DMA)

    .. table::

        ========================  ===  ================================  ===================
        Signal                    Dir  Width                             Description
        ========================  ===  ================================  ===================
        pcie_tx_wr_req_tlp_data   out  TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH  TLP payload
        pcie_tx_wr_req_tlp_strb   out  TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH  TLP byte enable
        pcie_tx_wr_req_tlp_hdr    out  TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH   TLP header
        pcie_tx_wr_req_tlp_seq    out  TLP_SEG_COUNT*TX_SEQ_NUM_WIDTH    TX seq num
        pcie_tx_wr_req_tlp_valid  out  TLP_SEG_COUNT                     Valid
        pcie_tx_wr_req_tlp_sop    out  TLP_SEG_COUNT                     Start of packet
        pcie_tx_wr_req_tlp_eop    out  TLP_SEG_COUNT                     End of packet
        pcie_tx_wr_req_tlp_ready  in   1                                 Ready
        ========================  ===  ================================  ===================

.. object:: s_axis_pcie_wr_req_tx_seq_num

    Transmit sequence number input (DMA write request)

    .. table::

        ===================================  ===  =================================  ===================
        Signal                               Dir  Width                              Description
        ===================================  ===  =================================  ===================
        s_axis_pcie_wr_req_tx_seq_num        in   TX_SEQ_NUM_COUNT*TX_SEQ_NUM_WIDTH  TX seq num
        s_axis_pcie_wr_req_tx_seq_num_valid  in   TX_SEQ_NUM_COUNT                   Valid
        ===================================  ===  =================================  ===================

.. object:: pcie_tx_cpl_tlp

    TLP output (completion from BAR)

    .. table::

        =====================  ===  ================================  ===================
        Signal                 Dir  Width                             Description
        =====================  ===  ================================  ===================
        pcie_tx_cpl_tlp_data   out  TLP_SEG_COUNT*TLP_SEG_DATA_WIDTH  TLP payload
        pcie_tx_cpl_tlp_strb   out  TLP_SEG_COUNT*TLP_SEG_STRB_WIDTH  TLP byte enable
        pcie_tx_cpl_tlp_hdr    out  TLP_SEG_COUNT*TLP_SEG_HDR_WIDTH   TLP header
        pcie_tx_cpl_tlp_valid  out  TLP_SEG_COUNT                     Valid
        pcie_tx_cpl_tlp_sop    out  TLP_SEG_COUNT                     Start of packet
        pcie_tx_cpl_tlp_eop    out  TLP_SEG_COUNT                     End of packet
        pcie_tx_cpl_tlp_ready  in   1                                 Ready
        =====================  ===  ================================  ===================

.. object:: pcie_tx_fc

    Flow control credits

    .. table::

        =================  ===  =====  ===================
        Signal             Dir  Width  Description
        =================  ===  =====  ===================
        pcie_tx_fc_ph_av   in   8      Available posted header credits
        pcie_tx_fc_pd_av   in   12     Available posted data credits
        pcie_tx_fc_nph_av  in   8      Available non-posted header credits
        =================  ===  =====  ===================

.. object:: config

    Configuration inputs

    .. table::

        =====================  ===  =========  ===================
        Signal                 Dir  Width      Description
        =====================  ===  =========  ===================
        bus_num                in   8          Bus number
        ext_tag_enable         in   F_COUNT    Extended tag enable
        max_read_request_size  in   F_COUNT*3  Max read request size
        max_payload_size       in   F_COUNT*3  Max payload size
        =====================  ===  =========  ===================

.. object:: pcie_error

    PCIe error outputs

    .. table::

        ================  ===  =====  ===================
        Signal            Dir  Width  Description
        ================  ===  =====  ===================
        pcie_error_cor    out  1      Correctable error
        pcie_error_uncor  out  1      Uncorrectable error
        ================  ===  =====  ===================

.. object:: msi_irq

    MSI request outputs

    .. table::

        =======  ===  =========  ===================
        Signal   Dir  Width      Description
        =======  ===  =========  ===================
        msi_irq  out  MSI_COUNT  Interrupt request
        =======  ===  =========  ===================
