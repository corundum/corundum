.. _mod_mqnic_core_pcie_us:

======================
``mqnic_core_pcie_us``
======================

``mqnic_core_pcie_us`` is the core integration-level module for mqnic for the PCIe host interface on Xilinx Virtex 7, UltraScale, and UltraScale+ series devices.  Wrapper around :ref:`mod_mqnic_core_pcie`, adding device-specific shims for the PCIe interface.

``mqnic_core_pcie_us`` integrates the following modules:

* ``pcie_us_if``: PCIe interface shim
* :ref:`mod_mqnic_core_pcie`: core logic for PCI express

Parameters
==========

Only parameters implemented in the wrapper are described here, for the other parameters see :ref:`mod_mqnic_core_pcie`.

.. object:: AXIS_PCIE_DATA_WIDTH

    PCIe AXI stream ``tdata`` signal width, default ``256``.

.. object:: AXIS_PCIE_KEEP_WIDTH

    PCIe AXI stream ``tkeep`` signal width, must be set to ``(AXIS_PCIE_DATA_WIDTH/32)``.

.. object:: AXIS_PCIE_RC_USER_WIDTH

    PCIe AXI stream RC ``tuser`` signal width, default ``AXIS_PCIE_DATA_WIDTH < 512 ? 75 : 161``.

.. object:: AXIS_PCIE_RQ_USER_WIDTH

    PCIe AXI stream RQ ``tuser`` signal width, default ``AXIS_PCIE_DATA_WIDTH < 512 ? 62 : 137``.

.. object:: AXIS_PCIE_CQ_USER_WIDTH

    PCIe AXI stream CQ ``tuser`` signal width, default ``AXIS_PCIE_DATA_WIDTH < 512 ? 85 : 183``.

.. object:: AXIS_PCIE_CC_USER_WIDTH

    PCIe AXI stream CC ``tuser`` signal width, default ``AXIS_PCIE_DATA_WIDTH < 512 ? 33 : 81``.

.. object:: RQ_SEQ_NUM_WIDTH

    PCIe RQ sequence number width, default ``AXIS_PCIE_RQ_USER_WIDTH == 60 ? 4 : 6``.

Ports
=====

Only ports implemented in the wrapper are described here, for the other ports see :ref:`mod_mqnic_core_pcie`.

.. object:: s_axis_rc

    AXI input (RC)

    .. table::

        ================  ===  =======================  ===================
        Signal            Dir  Width                    Description
        ================  ===  =======================  ===================
        s_axis_rc_tdata   in   AXIS_PCIE_DATA_WIDTH     TLP data
        s_axis_rc_tkeep   in   AXIS_PCIE_KEEP_WIDTH     Byte enable
        s_axis_rc_tvalid  in   1                        Valid
        s_axis_rc_tready  out  1                        Ready
        s_axis_rc_tlast   in   1                        End of frame
        s_axis_rc_tuser   in   AXIS_PCIE_RC_USER_WIDTH  Sideband data
        ================  ===  =======================  ===================

.. object:: m_axis_rq

    AXI output (RQ)

    .. table::

        ================  ===  =======================  ===================
        Signal            Dir  Width                    Description
        ================  ===  =======================  ===================
        m_axis_rq_tdata   out  AXIS_PCIE_DATA_WIDTH     TLP data
        m_axis_rq_tkeep   out  AXIS_PCIE_KEEP_WIDTH     Byte enable
        m_axis_rq_tvalid  out  1                        Valid
        m_axis_rq_tready  in   1                        Ready
        m_axis_rq_tlast   out  1                        End of frame
        m_axis_rq_tuser   out  AXIS_PCIE_RQ_USER_WIDTH  Sideband data
        ================  ===  =======================  ===================

.. object:: s_axis_cq

    AXI input (CQ)

    .. table::

        ================  ===  =======================  ===================
        Signal            Dir  Width                    Description
        ================  ===  =======================  ===================
        s_axis_cq_tdata   in   AXIS_PCIE_DATA_WIDTH     TLP data
        s_axis_cq_tkeep   in   AXIS_PCIE_KEEP_WIDTH     Byte enable
        s_axis_cq_tvalid  in   1                        Valid
        s_axis_cq_tready  out  1                        Ready
        s_axis_cq_tlast   in   1                        End of frame
        s_axis_cq_tuser   in   AXIS_PCIE_CQ_USER_WIDTH  Sideband data
        ================  ===  =======================  ===================

.. object:: m_axis_cc

    AXI output (CC)

    .. table::

        ================  ===  =======================  ===================
        Signal            Dir  Width                    Description
        ================  ===  =======================  ===================
        m_axis_cc_tdata   out  AXIS_PCIE_DATA_WIDTH     TLP data
        m_axis_cc_tkeep   out  AXIS_PCIE_KEEP_WIDTH     Byte enable
        m_axis_cc_tvalid  out  1                        Valid
        m_axis_cc_tready  in   1                        Ready
        m_axis_cc_tlast   out  1                        End of frame
        m_axis_cc_tuser   out  AXIS_PCIE_CC_USER_WIDTH  Sideband data
        ================  ===  =======================  ===================

.. object:: s_axis_rq_seq_num

    Transmit sequence number input

    .. table::

        =========================  ===  ================  ===================
        Signal                     Dir  Width             Description
        =========================  ===  ================  ===================
        s_axis_rq_seq_num_0        in   RQ_SEQ_NUM_WIDTH  Sequence number
        s_axis_rq_seq_num_valid_0  in   1                 Valid
        s_axis_rq_seq_num_1        in   RQ_SEQ_NUM_WIDTH  Sequence number
        s_axis_rq_seq_num_valid_1  in   1                 Valid
        =========================  ===  ================  ===================

.. object:: cfg_fc_ph

    Flow control

    .. table::

        ===========  ===  =====  ===================
        Signal       Dir  Width  Description
        ===========  ===  =====  ===================
        cfg_fc_ph    in   8      Posted header credits
        cfg_fc_pd    in   12     Posted data credits
        cfg_fc_nph   in   8      Non-posted header credits
        cfg_fc_npd   in   12     Non-posted data credits
        cfg_fc_cplh  in   8      Completion header credits
        cfg_fc_cpld  in   12     Completion data credits
        cfg_fc_sel   out  3      Credit select
        ===========  ===  =====  ===================

.. object:: cfg_max_read_req

    Configuration inputs

    .. table::

        ================  ===  =========  ===================
        Signal            Dir  Width      Description
        ================  ===  =========  ===================
        cfg_max_read_req  in   F_COUNT*3  Max read request
        cfg_max_payload   in   F_COUNT*3  Max payload
        ================  ===  =========  ===================

.. object:: cfg_mgmt_addr

    Configuration interface

    .. table::

        ========================  ===  =====  ===================
        Signal                    Dir  Width  Description
        ========================  ===  =====  ===================
        cfg_mgmt_addr             out  10     Address
        cfg_mgmt_function_number  out  8      Function number
        cfg_mgmt_write            out  1      Write enable
        cfg_mgmt_write_data       out  32     Write data
        cfg_mgmt_byte_enable      out  4      Byte enable
        cfg_mgmt_read             out  1      Read enable
        cfg_mgmt_read_data        in   32     Read data
        cfg_mgmt_read_write_done  in   1      Write done
        ========================  ===  =====  ===================

.. object:: cfg_interrupt_msi_enable

    Interrupt interface

    .. table::

        =============================================  ===  =====  ===================
        Signal                                         Dir  Width  Description
        =============================================  ===  =====  ===================
        cfg_interrupt_msi_enable                       in   4      MSI enable
        cfg_interrupt_msi_vf_enable                    in   8      VF enable
        cfg_interrupt_msi_mmenable                     in   12     MM enable
        cfg_interrupt_msi_mask_update                  in   1      Mask update
        cfg_interrupt_msi_data                         in   32     Data
        cfg_interrupt_msi_select                       out  4      Select
        cfg_interrupt_msi_int                          out  32     Interrupt request
        cfg_interrupt_msi_pending_status               out  32     Pending status
        cfg_interrupt_msi_pending_status_data_enable   out  1      Pending status enable
        cfg_interrupt_msi_pending_status_function_num  out  4      Pending status function
        cfg_interrupt_msi_sent                         in   1      MSI sent
        cfg_interrupt_msi_fail                         in   1      MSI fail
        cfg_interrupt_msi_attr                         out  3      MSI attr
        cfg_interrupt_msi_tph_present                  out  1      TPH present
        cfg_interrupt_msi_tph_type                     out  2      TPH type
        cfg_interrupt_msi_tph_st_tag                   out  9      TPH ST tag
        cfg_interrupt_msi_function_number              out  4      MSI function number
        =============================================  ===  =====  ===================

.. object:: status_error_cor

    PCIe error outputs

    .. table::

        ==================  ===  =====  ===================
        Signal              Dir  Width  Description
        ==================  ===  =====  ===================
        status_error_cor    out  1      Correctable error
        status_error_uncor  out  1      Uncorrectable error
        ==================  ===  =====  ===================
