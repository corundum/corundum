.. _mod_mqnic_core:

==============
``mqnic_core``
==============

``mqnic_core`` is the core integration-level module for mqnic for all host interfaces.  Contains the interfaces, asynchronous FIFOs, PTP subsystem, statistics collection subsystem, and application block.

For maximum flexibility, this module does not contain the actual host-facing DMA engine, so a wrapper is required to provide the DMA engine with the proper host-facing interface.  The available wrappers are:

* :ref:`mod_mqnic_core_pcie` for PCI express
* :ref:`mod_mqnic_core_axi` for AXI

``mqnic_core`` integrates the following modules:

* ``stats_counter``: statistics aggregation
* :ref:`mod_mqnic_ptp`: PTP subsystem
* :ref:`mod_mqnic_interface`: NIC interface
* :ref:`mod_mqnic_app_block`: Application block

Parameters
==========

.. object:: FPGA_ID

    FPGA JTAG ID, default is ``32'hDEADBEEF``.  Reported in :ref:`rb_fw_id`.

.. object:: FW_ID

    Firmware ID, default is ``32'h00000000``.  Reported in :ref:`rb_fw_id`.

.. object:: FW_VER

    Firmware version, default is ``32'h00_00_01_00``.  Reported in :ref:`rb_fw_id`.

.. object:: BOARD_ID

    Board ID, default is ``16'h1234_0000``.  Reported in :ref:`rb_fw_id`.

.. object:: BOARD_VER

    Board version, default is ``32'h01_00_00_00``.  Reported in :ref:`rb_fw_id`.

.. object:: BUILD_DATE

    Build date as a 32-bit unsigned Unix timestamp, default is ``32'd602976000``.  Reported in :ref:`rb_fw_id`.

.. object:: GIT_HASH

    32 bits of the git commit hash, default is ``32'hdce357bf``.  Reported in :ref:`rb_fw_id`.

.. object:: RELEASE_INFO

    Additional release info, default is ``32'h00000000``.  Reported in :ref:`rb_fw_id`.

.. object:: IF_COUNT

    Interface count, default ``1``.

.. object:: PORTS_PER_IF

    Ports per interface, default ``1``.

.. object:: SCHED_PER_IF

    Schedulers per interface, default ``PORTS_PER_IF``.

.. object:: PORT_COUNT

    Total port count, must be set to ``IF_COUNT*PORTS_PER_IF``.

.. object:: CLK_PERIOD_NS_NUM

    Numerator of core clock period in ns, default ``4``.

.. object:: CLK_PERIOD_NS_DENOM

    Denominator of core clock period in ns, default ``1``.

.. object:: PTP_CLK_PERIOD_NS_NUM

    Numerator of PTP clock period in ns, default ``4``.

.. object:: PTP_CLK_PERIOD_NS_DENOM

    Denominator of PTP clock period in ns, default ``1``.

.. object:: PTP_TS_WIDTH

    PTP timestamp width, must be ``96``.

.. object:: PTP_CLOCK_PIPELINE

    Output pipeline stages on PTP clock module, default ``0``.

.. object:: PTP_CLOCK_CDC_PIPELINE

    Output pipeline stages on PTP clock CDC module, default ``0``.

.. object:: PTP_USE_SAMPLE_CLOCK

    Use external PTP sample clock, used to synchronize the PTP clock across clock domains, default ``0``.

.. object:: PTP_SEPARATE_RX_CLOCK

    Use ``rx_ptp_clk`` instead of ``rx_clk`` for providing current PTP time if set, default ``0``.

.. object:: PTP_PORT_CDC_PIPELINE

    Output pipeline stages on PTP clock CDC module, default ``0``.

.. object:: PTP_PEROUT_ENABLE

    Enable PTP period output module, default ``0``.

.. object:: PTP_PEROUT_COUNT

    Number of PTP period output channels, default ``1``.

.. object:: EVENT_QUEUE_OP_TABLE_SIZE

    Event queue manager operation table size, default ``32``.

.. object:: TX_QUEUE_OP_TABLE_SIZE

    Transmit queue manager operation table size, default ``32``.

.. object:: RX_QUEUE_OP_TABLE_SIZE

    Receive queue manager operation table size, default ``32``.

.. object:: TX_CPL_QUEUE_OP_TABLE_SIZE

    Transmit completion queue operation table size, default ``TX_QUEUE_OP_TABLE_SIZE``.

.. object:: RX_CPL_QUEUE_OP_TABLE_SIZE

    Receive completion queue operation table size, default ``RX_QUEUE_OP_TABLE_SIZE``.

.. object:: EVENT_QUEUE_INDEX_WIDTH

    Event queue index width, default ``5``.  Sets the number of event queues on each interfaces as ``2**EVENT_QUEUE_INDEX_WIDTH``.

.. object:: TX_QUEUE_INDEX_WIDTH

    Transmit queue index width, default ``13``.  Sets the number of transmit queues on each interfaces as ``2**TX_QUEUE_INDEX_WIDTH``.

.. object:: RX_QUEUE_INDEX_WIDTH

    Receive queue index width, default ``8``.  Sets the number of receive queues on each interfaces as ``2**RX_QUEUE_INDEX_WIDTH``.

.. object:: TX_CPL_QUEUE_INDEX_WIDTH

    Transmit completion queue index width, default ``TX_QUEUE_INDEX_WIDTH``.  Sets the number of transmit completion queues on each interfaces as ``2**TX_CPL_QUEUE_INDEX_WIDTH``.

.. object:: RX_CPL_QUEUE_INDEX_WIDTH

    Receive completion queue index width, default ``RX_QUEUE_INDEX_WIDTH``.  Sets the number of receive completion queues on each interfaces as ``2**RX_CPL_QUEUE_INDEX_WIDTH``.

.. object:: EVENT_QUEUE_PIPELINE

    Event queue manager pipeline length, default ``3``.  Tune for best usage of block RAM cascade registers for specified queue count.

.. object:: TX_QUEUE_PIPELINE

    Transmit queue manager pipeline stages, default ``3+(TX_QUEUE_INDEX_WIDTH > 12 ? TX_QUEUE_INDEX_WIDTH-12 : 0)``.  Tune for best usage of block RAM cascade registers for specified queue count.

.. object:: RX_QUEUE_PIPELINE

    Receive queue manager pipeline stages, default ``3+(RX_QUEUE_INDEX_WIDTH > 12 ? RX_QUEUE_INDEX_WIDTH-12 : 0)``.  Tune for best usage of block RAM cascade registers for specified queue count.

.. object:: TX_CPL_QUEUE_PIPELINE

    Transmit completion queue manager pipeline stages, default ``TX_QUEUE_PIPELINE``.  Tune for best usage of block RAM cascade registers for specified queue count.

.. object:: RX_CPL_QUEUE_PIPELINE

    Receive completion queue manager pipeline stages, default ``RX_QUEUE_PIPELINE``.  Tune for best usage of block RAM cascade registers for specified queue count.

.. object:: TX_DESC_TABLE_SIZE

    Transmit engine descriptor table size, default ``32``.

.. object:: RX_DESC_TABLE_SIZE

    Receive engine descriptor table size, default ``32``.

.. object:: TX_SCHEDULER_OP_TABLE_SIZE

    Transmit scheduler operation table size, default ``TX_DESC_TABLE_SIZE``.

.. object:: TX_SCHEDULER_PIPELINE

    Transmit scheduler pipeline stages, default ``TX_QUEUE_PIPELINE``.  Tune for best usage of block RAM cascade registers for specified queue count.

.. object:: TDMA_INDEX_WIDTH

    TDMA index width, default ``6``.  Sets the number of TDMA timeslots as ``2**TDMA_INDEX_WIDTH``.

.. object:: PTP_TS_ENABLE

    Enable PTP timestamping, default ``1``.

.. object:: TX_CPL_ENABLE

    Enable transmit completions from MAC, default ``1``.

.. object:: TX_CPL_FIFO_DEPTH

    Depth of transmit completion FIFO, default ``32``.

.. object:: TX_TAG_WIDTH

    Transmit tag signal width, default ``$clog2(TX_DESC_TABLE_SIZE)+1``.

.. object:: TX_CHECKSUM_ENABLE

    Enable TCP/UDP checksum offloading on transmit path, default ``1``.

.. object:: RX_HASH_ENABLE

    Enable Toeplitz flow hashing and receive side scaling for RX traffic, default ``1``.

.. object:: RX_CHECKSUM_ENABLE

    Enable TCP/UDP checksum offloading on receive path, default ``1``

.. object:: TX_FIFO_DEPTH

    Transmit FIFO depth in bytes, per output port, per traffic class, default ``32768``.

.. object:: RX_FIFO_DEPTH

    Receive FIFO depth in bytes, per output port, default ``32768``.

.. object:: MAX_TX_SIZE

    Maximum packet size on transmit path, default ``9214``.

.. object:: MAX_RX_SIZE

    Maximum packet size on receive path, default ``9214``.

.. object:: TX_RAM_SIZE

    Transmit scratchpad RAM size per interface, default ``32768``.

.. object:: RX_RAM_SIZE

    Receive scratchpad RAM size per interface, default ``32768``.

.. object:: DDR_CH

    Number of DDR memory interfaces, default ``1``.

.. object:: DDR_ENABLE

    Enable DDR memory interfaces, default ``0``.

.. object:: DDR_GROUP_SIZE

    DDR channel group size, default ``1``.  All channels in each group share the same address space.

.. object:: AXI_DDR_DATA_WIDTH

    DDR memory interface AXI data width, default ``256``.

.. object:: AXI_DDR_ADDR_WIDTH

    DDR memory interface AXI address width, default ``32``.

.. object:: AXI_DDR_STRB_WIDTH

    DDR memory interface AXI strobe width, default ``(AXI_DDR_DATA_WIDTH/8)``.

.. object:: AXI_DDR_ID_WIDTH

    DDR memory interface AXI ID width, default ``8``.

.. object:: AXI_DDR_AWUSER_ENABLE

    DDR memory interface AXI AWUSER signal enable, default ``0``.

.. object:: AXI_DDR_AWUSER_WIDTH

    DDR memory interface AXI AWUSER signal width, default ``1``.

.. object:: AXI_DDR_WUSER_ENABLE

    DDR memory interface AXI WUSER signal enable, default ``0``.

.. object:: AXI_DDR_WUSER_WIDTH

    DDR memory interface AXI WUSER signal width, default ``1``.

.. object:: AXI_DDR_BUSER_ENABLE

    DDR memory interface AXI BUSER signal enable, default ``0``.

.. object:: AXI_DDR_BUSER_WIDTH

    DDR memory interface AXI BUSER signal width, default ``1``.

.. object:: AXI_DDR_ARUSER_ENABLE

    DDR memory interface AXI ARUSER signal enable, default ``0``.

.. object:: AXI_DDR_ARUSER_WIDTH

    DDR memory interface AXI ARUSER signal width, default ``1``.

.. object:: AXI_DDR_RUSER_ENABLE

    DDR memory interface AXI RUSER signal enable, default ``0``.

.. object:: AXI_DDR_RUSER_WIDTH

    DDR memory interface AXI RUSER signal width, default ``1``.

.. object:: AXI_DDR_MAX_BURST_LEN

    DDR memory interface max AXI burst length, default ``256``.

.. object:: AXI_DDR_NARROW_BURST

    DDR memory interface AXI narrow burst support, default ``0``.

.. object:: AXI_DDR_FIXED_BURST

    DDR memory interface AXI fixed burst support, default ``0``.

.. object:: AXI_DDR_WRAP_BURST

    DDR memory interface AXI wrap burst support, default ``0``.

.. object:: HBM_CH

    Number of HBM memory interfaces, default ``1``.

.. object:: HBM_ENABLE

    Enable HBM memory interfaces, default ``0``.

.. object:: HBM_GROUP_SIZE

    HBM channel group size, default ``1``.  All channels in each group share the same address space.

.. object:: AXI_HBM_DATA_WIDTH

    HBM memory interface AXI data width, default ``256``.

.. object:: AXI_HBM_AHBM_WIDTH

    HBM memory interface AXI address width, default ``32``.

.. object:: AXI_HBM_STRB_WIDTH

    HBM memory interface AXI strobe width, default ``(AXI_HBM_DATA_WIDTH/8)``.

.. object:: AXI_HBM_ID_WIDTH

    HBM memory interface AXI ID width, default ``8``.

.. object:: AXI_HBM_AWUSER_ENABLE

    HBM memory interface AXI AWUSER signal enable, default ``0``.

.. object:: AXI_HBM_AWUSER_WIDTH

    HBM memory interface AXI AWUSER signal width, default ``1``.

.. object:: AXI_HBM_WUSER_ENABLE

    HBM memory interface AXI WUSER signal enable, default ``0``.

.. object:: AXI_HBM_WUSER_WIDTH

    HBM memory interface AXI WUSER signal width, default ``1``.

.. object:: AXI_HBM_BUSER_ENABLE

    HBM memory interface AXI BUSER signal enable, default ``0``.

.. object:: AXI_HBM_BUSER_WIDTH

    HBM memory interface AXI BUSER signal width, default ``1``.

.. object:: AXI_HBM_ARUSER_ENABLE

    HBM memory interface AXI ARUSER signal enable, default ``0``.

.. object:: AXI_HBM_ARUSER_WIDTH

    HBM memory interface AXI ARUSER signal width, default ``1``.

.. object:: AXI_HBM_RUSER_ENABLE

    HBM memory interface AXI RUSER signal enable, default ``0``.

.. object:: AXI_HBM_RUSER_WIDTH

    HBM memory interface AXI RUSER signal width, default ``1``.

.. object:: AXI_HBM_MAX_BURST_LEN

    HBM memory interface max AXI burst length, default ``256``.

.. object:: AXI_HBM_NARROW_BURST

    HBM memory interface AXI narrow burst support, default ``0``.

.. object:: AXI_HBM_FIXED_BURST

    HBM memory interface AXI fixed burst support, default ``0``.

.. object:: AXI_HBM_WRAP_BURST

    HBM memory interface AXI wrap burst support, default ``0``.

.. object:: APP_ID

    Application ID, default ``0``.

.. object:: APP_ENABLE

    Enable application section, default ``0``.

.. object:: APP_CTRL_ENABLE

    Enable application section control connection to core NIC registers, default ``1``.

.. object:: APP_DMA_ENABLE

    Enable application section connection to DMA subsystem, default ``1``.

.. object:: APP_AXIS_DIRECT_ENABLE

    Enable lowest-latency asynchronous streaming connection to application section, default ``1``

.. object:: APP_AXIS_SYNC_ENABLE

    Enable low-latency synchronous streaming connection to application section, default ``1``

.. object:: APP_AXIS_IF_ENABLE

    Enable interface-level streaming connection to application section, default ``1``

.. object:: APP_STAT_ENABLE

    Enable application section connection to statistics collection subsystem, default ``1``

.. object:: APP_GPIO_IN_WIDTH

    Application section GPIO input signal width, default ``32``

.. object:: APP_GPIO_OUT_WIDTH

    Application section GPIO output signal width, default ``32``

.. object:: DMA_ADDR_WIDTH

    DMA interface address signal width, default ``64``.

.. object:: DMA_IMM_ENABLE

    DMA interface immediate enable, default ``0``.

.. object:: DMA_IMM_WIDTH

    DMA interface immediate signal width, default ``32``.

.. object:: DMA_LEN_WIDTH

    DMA interface length signal width, default ``16``.

.. object:: DMA_TAG_WIDTH

    DMA interface tag signal width, default ``16``.

.. object:: IF_RAM_SEL_WIDTH

    Width of interface-level select signal, default ``1``.

.. object:: RAM_SEL_WIDTH

    Width of select signal per segment in DMA RAM interface, default ``$clog2(IF_COUNT+(APP_ENABLE && APP_DMA_ENABLE ? 1 : 0))+IF_RAM_SEL_WIDTH+1``.

.. object:: RAM_ADDR_WIDTH

    Width of address signal for DMA RAM interface, default ``$clog2(TX_RAM_SIZE > RX_RAM_SIZE ? TX_RAM_SIZE : RX_RAM_SIZE)``.

.. object:: RAM_SEG_COUNT

    Number of segments in DMA RAM interface, default ``2``.  Must be a power of 2, must be at least 2.

.. object:: RAM_SEG_DATA_WIDTH

    Width of data signal per segment in DMA RAM interface, default ``256*2/RAM_SEG_COUNT``.

.. object:: RAM_SEG_BE_WIDTH

    Width of byte enable signal per segment in DMA RAM interface, must be set to ``RAM_SEG_DATA_WIDTH/8``.

.. object:: RAM_SEG_ADDR_WIDTH

    Width of address signal per segment in DMA RAM interface, default ``RAM_ADDR_WIDTH-$clog2(RAM_SEG_COUNT*RAM_SEG_BE_WIDTH)``.

.. object:: RAM_PIPELINE

    Number of output pipeline stages in segmented DMA RAMs, default ``2``.  Tune for best usage of block RAM cascade registers.

.. object:: MSI_COUNT

    Number of interrupt channels, default ``32``.

.. object:: AXIL_CTRL_DATA_WIDTH

    AXI lite control data signal width, must be set to ``32``.

.. object:: AXIL_CTRL_ADDR_WIDTH

    AXI lite control address signal width, default ``16``.

.. object:: AXIL_CTRL_STRB_WIDTH

    AXI lite control byte enable signal width, must be set to ``AXIL_CTRL_DATA_WIDTH/8``.

.. object:: AXIL_IF_CTRL_ADDR_WIDTH

    AXI lite interface control address signal width, default ``AXIL_CTRL_ADDR_WIDTH-$clog2(IF_COUNT)``

.. object:: AXIL_CSR_ADDR_WIDTH

    AXI lite interface CSR address signal width, default ``AXIL_IF_CTRL_ADDR_WIDTH-5-$clog2((PORTS_PER_IF+3)/8)``

.. object:: AXIL_CSR_PASSTHROUGH_ENABLE

    Enable NIC control register space passthrough, default ``0``.

.. object:: RB_NEXT_PTR

    Next pointer of last register block in the NIC-level CSR space, default ``0``.

.. object:: AXIL_APP_CTRL_DATA_WIDTH

    AXI lite application control data signal width, default ``AXIL_CTRL_DATA_WIDTH``.  Can be 32 or 64.

.. object:: AXIL_APP_CTRL_ADDR_WIDTH

    AXI lite application control address signal width, default ``16``.

.. object:: AXIL_APP_CTRL_STRB_WIDTH

    AXI lite application control byte enable signal width, must be set to ``AXIL_APP_CTRL_DATA_WIDTH/8``.

.. object:: AXIS_DATA_WIDTH

    Streaming interface ``tdata`` signal width, default ``512``.

.. object:: AXIS_KEEP_WIDTH

    Streaming interface ``tkeep`` signal width, must be set to ``AXIS_DATA_WIDTH/8``.

.. object:: AXIS_SYNC_DATA_WIDTH

    Synchronous streaming interface ``tdata`` signal width, default ``AXIS_DATA_WIDTH``.

.. object:: AXIS_IF_DATA_WIDTH

    Interface streaming interface ``tdata`` signal width, default ``AXIS_SYNC_DATA_WIDTH*2**$clog2(PORTS_PER_IF)``.

.. object:: AXIS_TX_USER_WIDTH

    Transmit streaming interface ``tuser`` signal width, default ``TX_TAG_WIDTH + 1``.

.. object:: AXIS_RX_USER_WIDTH

    Receive streaming interface ``tuser`` signal width, default ``(PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1``.

.. object:: AXIS_RX_USE_READY

    Use ``tready`` signal on RX interfaces, default ``0``.  If set, logic will exert backpressure with ``tready`` instead of dropping packets when RX FIFOs are full.

.. object:: AXIS_TX_PIPELINE

    Number of stages in transmit path pipeline FIFO, default ``0``.  Useful for SLR crossings.

.. object:: AXIS_TX_FIFO_PIPELINE

    Number of output pipeline stages in transmit FIFO, default ``2``.  Tune for best usage of block RAM cascade registers.

.. object:: AXIS_TX_TS_PIPELINE

    Number of stages in transmit path PTP timestamp pipeline FIFO, default ``0``.  Useful for SLR crossings.

.. object:: AXIS_RX_PIPELINE

    Number of stages in receive path pipeline FIFO, default ``0``.  Useful for SLR crossings.

.. object:: AXIS_RX_FIFO_PIPELINE

    Number of output pipeline stages in receive FIFO, default ``2``.  Tune for best usage of block RAM cascade registers.

.. object:: STAT_ENABLE

    Enable statistics collection subsystem, default ``1``.

.. object:: STAT_INC_WIDTH

    Statistics increment signal width, default ``24``.

.. object:: STAT_ID_WIDTH

    Statistics ID signal width, default ``12``.  Sets the number of statistics counters as ``2**STAT_ID_WIDTH``.

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

.. object:: s_axil_ctrl

    AXI-Lite slave interface (control).  This interface provides access to the main NIC control register space.

    .. table::

        ===================  ===  ====================  ===================
        Signal               Dir  Width                 Description
        ===================  ===  ====================  ===================
        s_axil_ctrl_awaddr   in   AXIL_CTRL_ADDR_WIDTH  Write address
        s_axil_ctrl_awprot   in   3                     Write protect
        s_axil_ctrl_awvalid  in   1                     Write address valid
        s_axil_ctrl_awready  out  1                     Write address ready
        s_axil_ctrl_wdata    in   AXIL_CTRL_DATA_WIDTH  Write data
        s_axil_ctrl_wstrb    in   AXIL_CTRL_STRB_WIDTH  Write data strobe
        s_axil_ctrl_wvalid   in   1                     Write data valid
        s_axil_ctrl_wready   out  1                     Write data ready
        s_axil_ctrl_bresp    out  2                     Write response status
        s_axil_ctrl_bvalid   out  1                     Write response valid
        s_axil_ctrl_bready   in   1                     Write response ready
        s_axil_ctrl_araddr   in   AXIL_CTRL_ADDR_WIDTH  Read address
        s_axil_ctrl_arprot   in   3                     Read protect
        s_axil_ctrl_arvalid  in   1                     Read address valid
        s_axil_ctrl_arready  out  1                     Read address ready
        s_axil_ctrl_rdata    out  AXIL_CTRL_DATA_WIDTH  Read response data
        s_axil_ctrl_rresp    out  2                     Read response status
        s_axil_ctrl_rvalid   out  1                     Read response valid
        s_axil_ctrl_rready   in   1                     Read response ready
        ===================  ===  ====================  ===================

.. object:: s_axil_app_ctrl

    AXI-Lite slave interface (application control).  This interface is directly passed through to the application section.

    .. table::

        =======================  ===  ========================  ===================
        Signal                   Dir  Width                     Description
        =======================  ===  ========================  ===================
        s_axil_app_ctrl_awaddr   in   AXIL_APP_CTRL_ADDR_WIDTH  Write address
        s_axil_app_ctrl_awprot   in   3                         Write protect
        s_axil_app_ctrl_awvalid  in   1                         Write address valid
        s_axil_app_ctrl_awready  out  1                         Write address ready
        s_axil_app_ctrl_wdata    in   AXIL_APP_CTRL_DATA_WIDTH  Write data
        s_axil_app_ctrl_wstrb    in   AXIL_APP_CTRL_STRB_WIDTH  Write data strobe
        s_axil_app_ctrl_wvalid   in   1                         Write data valid
        s_axil_app_ctrl_wready   out  1                         Write data ready
        s_axil_app_ctrl_bresp    out  2                         Write response status
        s_axil_app_ctrl_bvalid   out  1                         Write response valid
        s_axil_app_ctrl_bready   in   1                         Write response ready
        s_axil_app_ctrl_araddr   in   AXIL_APP_CTRL_ADDR_WIDTH  Read address
        s_axil_app_ctrl_arprot   in   3                         Read protect
        s_axil_app_ctrl_arvalid  in   1                         Read address valid
        s_axil_app_ctrl_arready  out  1                         Read address ready
        s_axil_app_ctrl_rdata    out  AXIL_APP_CTRL_DATA_WIDTH  Read response data
        s_axil_app_ctrl_rresp    out  2                         Read response status
        s_axil_app_ctrl_rvalid   out  1                         Read response valid
        s_axil_app_ctrl_rready   in   1                         Read response ready
        =======================  ===  ========================  ===================

.. object:: m_axil_csr

    AXI-Lite master interface (passthrough for NIC control and status).  This interface can be used to implement additional components in the main NIC control register space.

    .. table::

        ==================  ===  ====================  ===================
        Signal              Dir  Width                 Description
        ==================  ===  ====================  ===================
        m_axil_csr_awaddr   in   AXIL_CSR_ADDR_WIDTH   Write address
        m_axil_csr_awprot   in   3                     Write protect
        m_axil_csr_awvalid  in   1                     Write address valid
        m_axil_csr_awready  out  1                     Write address ready
        m_axil_csr_wdata    in   AXIL_CTRL_DATA_WIDTH  Write data
        m_axil_csr_wstrb    in   AXIL_CTRL_STRB_WIDTH  Write data strobe
        m_axil_csr_wvalid   in   1                     Write data valid
        m_axil_csr_wready   out  1                     Write data ready
        m_axil_csr_bresp    out  2                     Write response status
        m_axil_csr_bvalid   out  1                     Write response valid
        m_axil_csr_bready   in   1                     Write response ready
        m_axil_csr_araddr   in   AXIL_CTRL_ADDR_WIDTH  Read address
        m_axil_csr_arprot   in   3                     Read protect
        m_axil_csr_arvalid  in   1                     Read address valid
        m_axil_csr_arready  out  1                     Read address ready
        m_axil_csr_rdata    out  AXIL_CTRL_DATA_WIDTH  Read response data
        m_axil_csr_rresp    out  2                     Read response status
        m_axil_csr_rvalid   out  1                     Read response valid
        m_axil_csr_rready   in   1                     Read response ready
        ==================  ===  ====================  ===================

.. object:: ctrl_reg
    
    Control register interface.  This interface can be used to implement additional control registers and register blocks in the main NIC control register space.

    .. table::

        =================  ===  ====================  ===================
        Signal             Dir  Width                 Description
        =================  ===  ====================  ===================
        ctrl_reg_wr_addr   out  AXIL_CSR_ADDR_WIDTH   Write address
        ctrl_reg_wr_data   out  AXIL_CTRL_DATA_WIDTH  Write data
        ctrl_reg_wr_strb   out  AXIL_CTRL_STRB_WIDTH  Write strobe
        ctrl_reg_wr_en     out  1                     Write enable
        ctrl_reg_wr_wait   in   1                     Write wait
        ctrl_reg_wr_ack    in   1                     Write acknowledge
        ctrl_reg_rd_addr   out  AXIL_CSR_ADDR_WIDTH   Read address
        ctrl_reg_rd_en     out  1                     Read enable
        ctrl_reg_rd_data   in   AXIL_CTRL_DATA_WIDTH  Read data
        ctrl_reg_rd_wait   in   1                     Read wait
        ctrl_reg_rd_ack    in   1                     Read acknowledge
        =================  ===  ====================  ===================

.. object:: m_axis_dma_read_desc
    
    DMA read descriptor output

    .. table::

        =============================  ===  ==============  ===================
        Signal                         Dir  Width           Description
        =============================  ===  ==============  ===================
        m_axis_dma_read_desc_dma_addr  out  DMA_ADDR_WIDTH  DMA address
        m_axis_dma_read_desc_ram_sel   out  RAM_SEL_WIDTH   RAM select
        m_axis_dma_read_desc_ram_addr  out  RAM_ADDR_WIDTH  RAM address
        m_axis_dma_read_desc_len       out  DMA_LEN_WIDTH   Transfer length
        m_axis_dma_read_desc_tag       out  DMA_TAG_WIDTH   Transfer tag
        m_axis_dma_read_desc_valid     out  1               Request valid
        m_axis_dma_read_desc_ready     in   1               Request ready
        =============================  ===  ==============  ===================

.. object:: s_axis_dma_read_desc_status
    
    DMA read descriptor status input

    .. table::

        =================================  ===  =============  ===================
        Signal                             Dir  Width          Description
        =================================  ===  =============  ===================
        s_axis_dma_read_desc_status_tag    in   DMA_TAG_WIDTH  Status tag
        s_axis_dma_read_desc_status_error  in   4              Status error code
        s_axis_dma_read_desc_status_valid  in   1              Status valid
        =================================  ===  =============  ===================

.. object:: m_axis_dma_write_desc
    
    DMA write descriptor output

    .. table::

        ==============================  ===  ==============  ===================
        Signal                          Dir  Width           Description
        ==============================  ===  ==============  ===================
        m_axis_dma_write_desc_dma_addr  out  DMA_ADDR_WIDTH  DMA address
        m_axis_dma_write_desc_ram_sel   out  RAM_SEL_WIDTH   RAM select
        m_axis_dma_write_desc_ram_addr  out  RAM_ADDR_WIDTH  RAM address
        m_axis_dma_write_desc_imm       out  DMA_IMM_WIDTH   Immediate
        m_axis_dma_write_desc_imm_en    out  1               Immediate enable
        m_axis_dma_write_desc_len       out  DMA_LEN_WIDTH   Transfer length
        m_axis_dma_write_desc_tag       out  DMA_TAG_WIDTH   Transfer tag
        m_axis_dma_write_desc_valid     out  1               Request valid
        m_axis_dma_write_desc_ready     in   1               Request ready
        ==============================  ===  ==============  ===================

.. object:: s_axis_dma_write_desc_status

    DMA write descriptor status input

    .. table::

        ==================================  ===  =============  ===================
        Signal                              Dir  Width          Description
        ==================================  ===  =============  ===================
        s_axis_dma_write_desc_status_tag    in   DMA_TAG_WIDTH  Status tag
        s_axis_dma_write_desc_status_error  in   4              Status error code
        s_axis_dma_write_desc_status_valid  in   1              Status valid
        ==================================  ===  =============  ===================

.. object:: dma_ram

    DMA RAM interface

    .. table::

        =====================  ===  ================================  ===================
        Signal                 Dir  Width                             Description
        =====================  ===  ================================  ===================
        dma_ram_wr_cmd_sel     in   RAM_SEG_COUNT*RAM_SEL_WIDTH       Write command select
        dma_ram_wr_cmd_be      in   RAM_SEG_COUNT*RAM_SEG_BE_WIDTH    Write command byte enable
        dma_ram_wr_cmd_addr    in   RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH  Write command address
        dma_ram_wr_cmd_data    in   RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH  Write command data
        dma_ram_wr_cmd_valid   in   RAM_SEG_COUNT                     Write command valid
        dma_ram_wr_cmd_ready   out  RAM_SEG_COUNT                     Write command ready
        dma_ram_wr_done        out  RAM_SEG_COUNT                     Write done
        dma_ram_rd_cmd_sel     in   RAM_SEG_COUNT*RAM_SEL_WIDTH       Read command select
        dma_ram_rd_cmd_addr    in   RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH  Read command address
        dma_ram_rd_cmd_valid   in   RAM_SEG_COUNT                     Read command valid
        dma_ram_rd_cmd_ready   out  RAM_SEG_COUNT                     Read command ready
        dma_ram_rd_resp_data   out  RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH  Read response data
        dma_ram_rd_resp_valid  out  RAM_SEG_COUNT                     Read response valid
        dma_ram_rd_resp_ready  in   RAM_SEG_COUNT                     Read response ready
        =====================  ===  ================================  ===================

.. object:: msi_irq

    MSI request outputs

    .. table::

        =======  ===  =========  ===================
        Signal   Dir  Width      Description
        =======  ===  =========  ===================
        msi_irq  out  MSI_COUNT  Interrupt request
        =======  ===  =========  ===================

.. object:: ptp

    PTP clock connections.

    .. table::

        =================  ===  ================  ===================
        Signal             Dir  Width             Description
        =================  ===  ================  ===================
        ptp_clk            in   1                 PTP clock
        ptp_rst            in   1                 PTP reset
        ptp_sample_clk     in   1                 PTP sample clock
        ptp_pps            out  1                 PTP pulse-per-second (synchronous to ptp_clk)
        ptp_pps_str        out  1                 PTP pulse-per-second (stretched) (synchronous to ptp_clk)
        ptp_ts_96          out  PTP_TS_WIDTH      current PTP time (synchronous to ptp_clk)
        ptp_ts_step        out  1                 PTP clock step (synchronous to ptp_clk)
        ptp_sync_pps       out  1                 PTP pulse-per-second (synchronous to clk)
        ptp_sync_ts_96     out  PTP_TS_WIDTH      current PTP time (synchronous to clk)
        ptp_sync_ts_step   out  1                 PTP clock step (synchronous to clk)
        ptp_perout_locked  out  PTP_PEROUT_COUNT  PTP period output locked
        ptp_perout_error   out  PTP_PEROUT_COUNT  PTP period output error
        ptp_perout_pulse   out  PTP_PEROUT_COUNT  PTP period output pulse
        =================  ===  ================  ===================

.. object:: tx_clk

    Transmit clocks, one per port

    .. table::

        ======  ===  ==========  ==================
        Signal  Dir  Width       Description
        ======  ===  ==========  ==================
        tx_clk  in   PORT_COUNT  Transmit clock
        ======  ===  ==========  ==================

.. object:: tx_rst

    Transmit resets, one per port

    .. table::

        ======  ===  ==========  ==================
        Signal  Dir  Width       Description
        ======  ===  ==========  ==================
        tx_rst  in   PORT_COUNT  Transmit reset
        ======  ===  ==========  ==================

.. object:: tx_ptp_ts

    Reference PTP time for transmit timestamping synchronous to each transmit clock, one per port.

    .. table::

        ==============  ===  =======================  ==================
        Signal          Dir  Width                    Description
        ==============  ===  =======================  ==================
        tx_ptp_ts_96    out  PORT_COUNT*PTP_TS_WIDTH  current PTP time
        tx_ptp_ts_step  out  PORT_COUNT               PTP clock step
        ==============  ===  =======================  ==================

.. object:: m_axis_tx

    Streaming transmit data towards network, one AXI stream interface per port.

    .. table::

        ================  ===  =============================  ==================
        Signal            Dir  Width                          Description
        ================  ===  =============================  ==================
        m_axis_tx_tdata   out  PORT_COUNT*AXIS_DATA_WIDTH     Streaming data
        m_axis_tx_tkeep   out  PORT_COUNT*AXIS_KEEP_WIDTH     Byte enable
        m_axis_tx_tvalid  out  PORT_COUNT                     Data valid
        m_axis_tx_tready  in   PORT_COUNT                     Ready for data
        m_axis_tx_tlast   out  PORT_COUNT                     End of frame
        m_axis_tx_tuser   out  PORT_COUNT*AXIS_TX_USER_WIDTH  Sideband data
        ================  ===  =============================  ==================

    ``s_axis_tx_tuser`` bits, per port

    .. table::

        ===============  =========  =============  =============
        Bit              Name       Width          Description
        ===============  =========  =============  =============
        0                bad_frame  1              Invalid frame
        TX_TAG_WIDTH:1   tx_tag     TX_TAG_WIDTH   Transmit tag
        ===============  =========  =============  =============

.. object:: s_axis_tx_cpl

    Transmit completion, one AXI stream interface per port.

    .. table::

        ======================  ===  ========================  ===================
        Signal                  Dir  Width                     Description
        ======================  ===  ========================  ===================
        s_axis_tx_cpl_ts        in   PORT_COUNT*PTP_TS_WIDTH   PTP timestamp
        s_axis_tx_cpl_tag       in   PORT_COUNT*TX_TAG_WIDTH   Transmit tag
        s_axis_tx_cpl_valid     in   PORT_COUNT                Transmit completion valid
        s_axis_tx_cpl_ready     out  PORT_COUNT                Transmit completion ready
        ======================  ===  ========================  ===================

.. object:: tx_status

    Transmit link status inputs, one per port

    .. table::

        =========  ===  ==========  ==================
        Signal     Dir  Width       Description
        =========  ===  ==========  ==================
        tx_status  in   PORT_COUNT  Transmit link status
        =========  ===  ==========  ==================

.. object:: rx_clk

    Receive clocks, one per port

    .. table::

        ======  ===  ==========  ==================
        Signal  Dir  Width       Description
        ======  ===  ==========  ==================
        rx_clk  in   PORT_COUNT  Receive clock
        ======  ===  ==========  ==================

.. object:: rx_rst

    Receive resets, one per port

    .. table::

        ======  ===  ==========  ==================
        Signal  Dir  Width       Description
        ======  ===  ==========  ==================
        rx_rst  in   PORT_COUNT  Receive reset
        ======  ===  ==========  ==================

.. object:: rx_ptp_ts

    Reference PTP time for receive timestamping synchronous to each receive clock, one per port.  Synchronous to ``rx_ptp_clk`` if ``PTP_SEPARATE_RX_CLOCK`` is set.

    .. table::

        ==============  ===  =======================  ==================
        Signal          Dir  Width                    Description
        ==============  ===  =======================  ==================
        rx_ptp_clk      in   PORT_COUNT               clock for PTP time
        rx_ptp_rst      in   PORT_COUNT               reset for PTP time
        rx_ptp_ts_96    out  PORT_COUNT*PTP_TS_WIDTH  current PTP time
        rx_ptp_ts_step  out  PORT_COUNT               PTP clock step
        ==============  ===  =======================  ==================

.. object:: s_axis_rx

    Streaming receive data from network, one AXI stream interface per port.

    .. table::

        ================  ===  =============================  ==================
        Signal            Dir  Width                          Description
        ================  ===  =============================  ==================
        s_axis_rx_tdata   in   PORT_COUNT*AXIS_DATA_WIDTH     Streaming data
        s_axis_rx_tkeep   in   PORT_COUNT*AXIS_KEEP_WIDTH     Byte enable
        s_axis_rx_tvalid  in   PORT_COUNT                     Data valid
        s_axis_rx_tready  out  PORT_COUNT                     Ready for data
        s_axis_rx_tlast   in   PORT_COUNT                     End of frame
        s_axis_rx_tuser   in   PORT_COUNT*AXIS_TX_USER_WIDTH  Sideband data
        ================  ===  =============================  ==================

    ``s_axis_rx_tuser`` bits, per port

    .. table::

        ==============  =========  ============  =============
        Bit             Name       Width         Description
        ==============  =========  ============  =============
        0               bad_frame  1             Invalid frame
        PTP_TS_WIDTH:1  ptp_ts     PTP_TS_WIDTH  PTP timestamp
        ==============  =========  ============  =============

.. object:: rx_status

    Receive link status inputs, one per port

    .. table::

        =========  ===  ==========  ==================
        Signal     Dir  Width       Description
        =========  ===  ==========  ==================
        rx_status  in   PORT_COUNT  Receive link status
        =========  ===  ==========  ==================

.. object:: s_axis_stat

    Statistics increment input

    .. table::

        ==================  ===  ==============  ===================
        Signal              Dir  Width           Description
        ==================  ===  ==============  ===================
        s_axis_stat_tdata   in   STAT_INC_WIDTH  Statistic increment
        s_axis_stat_tid     in   STAT_ID_WIDTH   Statistic ID
        s_axis_stat_tvalid  in   1               Statistic valid
        s_axis_stat_tready  out  1               Statistic ready
        ==================  ===  ==============  ===================

.. object:: app_gpio

    Application section GPIO

    .. table::

        ============  ===  ==================  ===================
        Signal        Dir  Width               Description
        ============  ===  ==================  ===================
        app_gpio_in   in   APP_GPIO_IN_WIDTH   GPIO inputs
        app_gpio_out  out  APP_GPIO_OUT_WIDTH  GPIO outputs
        ============  ===  ==================  ===================

.. object:: app_jtag

    Application section JTAG scan chain

    .. table::

        ============  ===  =====  ===================
        Signal        Dir  Width  Description
        ============  ===  =====  ===================
        app_jtag_tdi  in   1      JTAG TDI
        app_jtag_tdo  out  1      JTAG TDO
        app_jtag_tms  in   1      JTAG TMS
        app_jtag_tck  in   1      JTAG TCK
        ============  ===  =====  ===================
