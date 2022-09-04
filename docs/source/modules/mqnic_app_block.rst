.. _mod_mqnic_app_block:

===================
``mqnic_app_block``
===================

``mqnic_app_block`` is the top-level block for application logic.  It is instantiated in :ref:`mod_mqnic_core`.  This is a pluggable module, intended to be replaced by a customized implementation via the build system.  See .... for more details.

A number of interfaces are provided:

* Clock and reset synchronous with core datapath
* Dedicated AXI-lite master interface for application control (``s_axil_app_ctrl``)
* AXI-lite slave interface for access to NIC control register space (``m_axil_ctrl``)
* Access to DMA subsystem (``*_axis_*_dma_*_desc``, ``*_dma_ram``)
* Access to PTP subsystem (``ptp_*``)
* Direct, MAC-synchronous, lowest-latency streaming interface (``*_axis_direct_*``)
* Direct, datapath-synchronous, low-latency streaming interface (``*_axis_sync_*``)
* Interface-level streaming interface (``*_axis_if_*``)
* Statistics interface (``m_axis_stat``)
* GPIO and JTAG passthrough (``gpio``, ``jtag``)

Packet data from the host passes through all three streaming interfaces on its way to the network, and vise-versa.  The three interfaces are:

1. ``*_axis_direct_*``: Direct, MAC-synchronous, lowest-latency streaming interface.  This interface is as close as possible to the main transmit and receive interfaces on :ref:`mod_mqnic_core`, and is synchronous to the TX and RX clocks instead of the core clock.  Enabled/bypassed via ``APP_AXIS_DIRECT_ENABLE`` in ``config.tcl``.
2. ``*_axis_sync_*``: Direct, datapath-synchronous, low-latency streaming interface.  This interface handles per-port data between the main transmit and receive FIFOs and the async FIFOs, and is synchronous to the core clock.  Enabled/bypassed via ``APP_AXIS_SYNC_ENABLE`` in ``config.tcl``.
3. ``*_axis_if_*``: Interface-level streaming interface.  This interface handles aggregated interface-level data between the host and the main receive and transmit FIFOs, and is synchronous to the core clock.  Enabled/bypassed via ``APP_AXIS_IF_ENABLE`` in ``config.tcl``.

On the transmit path, data flows as follows:

1. :ref:`mod_mqnic_interface_tx`: data is read from host memory via DMA
2. :ref:`mod_mqnic_egress`: egress processing
3. ``s_axis_if_tx``: data is presented to the application section
4. ``m_axis_if_tx``: data is returned from the application section
5. Data passes enters per-interface transmit FIFO module and is divided into per-port, per-traffic-class FIFOs
6. ``s_axis_sync_tx``: data is presented to the application section
7. ``m_axis_sync_tx``: data is returned from the application section
8. Data passes through per-port transmit async FIFO module and is transferred to MAC TX clock domain
9. ``s_axis_direct_tx``: data is presented to the application section
10. ``m_axis_direct_tx``: data is returned from the application section
11. :ref:`mod_mqnic_l2_egress`: layer 2 egress processing
12. :ref:`mod_mqnic_core`: data leaves through transmit streaming interfaces

On the receive path, data flows as follows:

1. :ref:`mod_mqnic_core`: data enters through receive streaming interfaces
2. :ref:`mod_mqnic_l2_ingress`: layer 2 ingress processing
3. ``s_axis_direct_rx``: data is presented to the application section
4. ``m_axis_direct_rx``: data is returned from the application section
5. Data passes through per-port receive async FIFO module and is transferred to core clock domain
6. ``s_axis_sync_rx``: data is presented to the application section
7. ``m_axis_sync_rx``: data is returned from the application section
8. Data passes enters per-interface receive FIFO module and is placed into per-port FIFOs, then aggregated into a single stream
9. ``s_axis_if_rx``: data is presented to the application section
10. ``m_axis_if_rx``: data is returned from the application section
11. :ref:`mod_mqnic_ingress`: ingress processing
12. :ref:`mod_mqnic_interface_rx`: data is read from host memory via DMA

Parameters
==========

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

.. object:: PTP_USE_SAMPLE_CLOCK

    Use external PTP sample clock, used to synchronize the PTP clock across clock domains.  Default ``0``.

.. object:: PTP_PORT_CDC_PIPELINE

    Output pipeline stages on PTP clock CDC module, default ``0``.

.. object:: PTP_PEROUT_ENABLE

    Enable PTP period output module, default ``0``.

.. object:: PTP_PEROUT_COUNT

    Number of PTP period output channels, default ``1``.

.. object:: PTP_TS_ENABLE

    Enable PTP timestamping, default ``1``.

.. object:: TX_TAG_WIDTH

    Transmit tag signal width, default ``16``.

.. object:: MAX_TX_SIZE

    Maximum packet size on transmit path, default ``9214``.

.. object:: MAX_RX_SIZE

    Maximum packet size on receive path, default ``9214``.

.. object:: APP_ID

    Application ID, default ``0``.

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

.. object:: RAM_SEL_WIDTH

    Width of select signal per segment in DMA RAM interface, default ``4``.

.. object:: RAM_ADDR_WIDTH

    Width of address signal for DMA RAM interface, default ``16``.

.. object:: RAM_SEG_COUNT

    Number of segments in DMA RAM interface, default ``2``.  Must be a power of 2, must be at least 2.

.. object:: RAM_SEG_DATA_WIDTH

    Width of data signal per segment in DMA RAM interface, default ``256*2/RAM_SEG_COUNT``.

.. object:: RAM_SEG_BE_WIDTH

    Width of byte enable signal per segment in DMA RAM interface, default ``RAM_SEG_DATA_WIDTH/8``.

.. object:: RAM_SEG_ADDR_WIDTH

    Width of address signal per segment in DMA RAM interface, default ``RAM_ADDR_WIDTH-$clog2(RAM_SEG_COUNT*RAM_SEG_BE_WIDTH)``.

.. object:: RAM_PIPELINE

    Number of output pipeline stages in segmented DMA RAMs, default ``2``.  Tune for best usage of block RAM cascade registers.

.. object:: AXIL_APP_CTRL_DATA_WIDTH

    AXI lite application control data signal width, default ``AXIL_CTRL_DATA_WIDTH``.  Can be 32 or 64.

.. object:: AXIL_APP_CTRL_ADDR_WIDTH

    AXI lite application control address signal width, default ``16``.

.. object:: AXIL_APP_CTRL_STRB_WIDTH

    AXI lite application control byte enable signal width, must be set to ``AXIL_APP_CTRL_DATA_WIDTH/8``.

.. object:: AXIL_CTRL_DATA_WIDTH

    AXI lite control data signal width, default ``32``.  Must be 32.

.. object:: AXIL_CTRL_ADDR_WIDTH

    AXI lite control address signal width, default ``16``.

.. object:: AXIL_CTRL_STRB_WIDTH

    AXI lite control byte enable signal width, must be set to ``AXIL_CTRL_DATA_WIDTH/8``.

.. object:: AXIS_DATA_WIDTH

    Asynchronous streaming interface ``tdata`` signal width, default ``512``.

.. object:: AXIS_KEEP_WIDTH

    Asynchronous streaming interface ``tkeep`` signal width, must be set to ``AXIS_DATA_WIDTH/8``.

.. object:: AXIS_TX_USER_WIDTH

    Asynchronous streaming transmit interface ``tuser`` signal width, default ``TX_TAG_WIDTH + 1``.

.. object:: AXIS_RX_USER_WIDTH

    Asynchronous streaming receive interface ``tuser`` signal width, default ``(PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1``.

.. object:: AXIS_RX_USE_READY

    Use ``tready`` signal on RX interfaces, default ``0``.  If set, logic will exert backpressure with ``tready`` instead of dropping packets when RX FIFOs are full.

.. object:: AXIS_SYNC_DATA_WIDTH

    Synchronous streaming interface ``tdata`` signal width, default ``AXIS_DATA_WIDTH``.

.. object:: AXIS_SYNC_KEEP_WIDTH

    Synchronous streaming interface ``tkeep`` signal width, must be set to ``AXIS_SYNC_DATA_WIDTH/8``.

.. object:: AXIS_SYNC_TX_USER_WIDTH

    Synchronous streaming transmit interface ``tuser`` signal width, default ``AXIS_TX_USER_WIDTH``.

.. object:: AXIS_SYNC_RX_USER_WIDTH

    Synchronous streaming receive interface ``tuser`` signal width, default ``AXIS_RX_USER_WIDTH``.

.. object:: AXIS_IF_DATA_WIDTH

    Interface streaming interface ``tdata`` signal width, default ``AXIS_SYNC_DATA_WIDTH*2**$clog2(PORTS_PER_IF)``.

.. object:: AXIS_IF_KEEP_WIDTH

    Interface streaming interface ``tkeep`` signal width, must be set to ``AXIS_IF_DATA_WIDTH/8``.

.. object:: AXIS_IF_TX_ID_WIDTH

    Interface transmit streaming interface ``tid`` signal width, default ``12``.

.. object:: AXIS_IF_RX_ID_WIDTH

    Interface receive streaming interface ``tid`` signal width, default ``PORTS_PER_IF > 1 ? $clog2(PORTS_PER_IF) : 1``.

.. object:: AXIS_IF_TX_DEST_WIDTH

    Interface transmit streaming interface ``tdest`` signal width, default ``$clog2(PORTS_PER_IF)+4``.

.. object:: AXIS_IF_RX_DEST_WIDTH

    Interface receive streaming interface ``tdest`` signal width, default ``8``.

.. object:: AXIS_IF_TX_USER_WIDTH

    Interface transmit streaming interface ``tuser`` signal width, default ``AXIS_SYNC_TX_USER_WIDTH``.

.. object:: AXIS_IF_RX_USER_WIDTH

    Interface receive streaming interface ``tuser`` signal width, default ``AXIS_SYNC_RX_USER_WIDTH``.

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

.. object:: s_axil_app_ctrl

    AXI-Lite slave interface (application control).

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

.. object:: m_axil_ctrl

    AXI-Lite master interface (control).  This interface provides access to the main NIC control register space.

    .. table::

        ===================  ===  ====================  ===================
        Signal               Dir  Width                 Description
        ===================  ===  ====================  ===================
        m_axil_ctrl_awaddr   in   AXIL_CTRL_ADDR_WIDTH  Write address
        m_axil_ctrl_awprot   in   3                     Write protect
        m_axil_ctrl_awvalid  in   1                     Write address valid
        m_axil_ctrl_awready  out  1                     Write address ready
        m_axil_ctrl_wdata    in   AXIL_CTRL_DATA_WIDTH  Write data
        m_axil_ctrl_wstrb    in   AXIL_CTRL_STRB_WIDTH  Write data strobe
        m_axil_ctrl_wvalid   in   1                     Write data valid
        m_axil_ctrl_wready   out  1                     Write data ready
        m_axil_ctrl_bresp    out  2                     Write response status
        m_axil_ctrl_bvalid   out  1                     Write response valid
        m_axil_ctrl_bready   in   1                     Write response ready
        m_axil_ctrl_araddr   in   AXIL_CTRL_ADDR_WIDTH  Read address
        m_axil_ctrl_arprot   in   3                     Read protect
        m_axil_ctrl_arvalid  in   1                     Read address valid
        m_axil_ctrl_arready  out  1                     Read address ready
        m_axil_ctrl_rdata    out  AXIL_CTRL_DATA_WIDTH  Read response data
        m_axil_ctrl_rresp    out  2                     Read response status
        m_axil_ctrl_rvalid   out  1                     Read response valid
        m_axil_ctrl_rready   in   1                     Read response ready
        ===================  ===  ====================  ===================

.. object:: m_axis_ctrl_dma_read_desc
    
    DMA read descriptor output (control)

    .. table::

        ==================================  ===  ==============  ===================
        Signal                              Dir  Width           Description
        ==================================  ===  ==============  ===================
        m_axis_ctrl_dma_read_desc_dma_addr  out  DMA_ADDR_WIDTH  DMA address
        m_axis_ctrl_dma_read_desc_ram_sel   out  RAM_SEL_WIDTH   RAM select
        m_axis_ctrl_dma_read_desc_ram_addr  out  RAM_ADDR_WIDTH  RAM address
        m_axis_ctrl_dma_read_desc_len       out  DMA_LEN_WIDTH   Transfer length
        m_axis_ctrl_dma_read_desc_tag       out  DMA_TAG_WIDTH   Transfer tag
        m_axis_ctrl_dma_read_desc_valid     out  1               Request valid
        m_axis_ctrl_dma_read_desc_ready     in   1               Request ready
        ==================================  ===  ==============  ===================

.. object:: s_axis_ctrl_dma_read_desc_status
    
    DMA read descriptor status input (control)

    .. table::

        ======================================  ===  =============  ===================
        Signal                                  Dir  Width          Description
        ======================================  ===  =============  ===================
        s_axis_ctrl_dma_read_desc_status_tag    in   DMA_TAG_WIDTH  Status tag
        s_axis_ctrl_dma_read_desc_status_error  in   4              Status error code
        s_axis_ctrl_dma_read_desc_status_valid  in   1              Status valid
        ======================================  ===  =============  ===================

.. object:: m_axis_ctrl_dma_write_desc
    
    DMA write descriptor output (control)

    .. table::

        ===================================  ===  ==============  ===================
        Signal                               Dir  Width           Description
        ===================================  ===  ==============  ===================
        m_axis_ctrl_dma_write_desc_dma_addr  out  DMA_ADDR_WIDTH  DMA address
        m_axis_ctrl_dma_write_desc_ram_sel   out  RAM_SEL_WIDTH   RAM select
        m_axis_ctrl_dma_write_desc_ram_addr  out  RAM_ADDR_WIDTH  RAM address
        m_axis_ctrl_dma_write_desc_imm       out  DMA_IMM_WIDTH   Immediate
        m_axis_ctrl_dma_write_desc_imm_en    out  1               Immediate enable
        m_axis_ctrl_dma_write_desc_len       out  DMA_LEN_WIDTH   Transfer length
        m_axis_ctrl_dma_write_desc_tag       out  DMA_TAG_WIDTH   Transfer tag
        m_axis_ctrl_dma_write_desc_valid     out  1               Request valid
        m_axis_ctrl_dma_write_desc_ready     in   1               Request ready
        ===================================  ===  ==============  ===================

.. object:: s_axis_ctrl_dma_write_desc_status

    DMA write descriptor status input (control)

    .. table::

        =======================================  ===  =============  ===================
        Signal                                   Dir  Width          Description
        =======================================  ===  =============  ===================
        s_axis_ctrl_dma_write_desc_status_tag    in   DMA_TAG_WIDTH  Status tag
        s_axis_ctrl_dma_write_desc_status_error  in   4              Status error code
        s_axis_ctrl_dma_write_desc_status_valid  in   1              Status valid
        =======================================  ===  =============  ===================

.. object:: m_axis_data_dma_read_desc
    
    DMA read descriptor output (data)

    .. table::

        ==================================  ===  ==============  ===================
        Signal                              Dir  Width           Description
        ==================================  ===  ==============  ===================
        m_axis_data_dma_read_desc_dma_addr  out  DMA_ADDR_WIDTH  DMA address
        m_axis_data_dma_read_desc_ram_sel   out  RAM_SEL_WIDTH   RAM select
        m_axis_data_dma_read_desc_ram_addr  out  RAM_ADDR_WIDTH  RAM address
        m_axis_data_dma_read_desc_len       out  DMA_LEN_WIDTH   Transfer length
        m_axis_data_dma_read_desc_tag       out  DMA_TAG_WIDTH   Transfer tag
        m_axis_data_dma_read_desc_valid     out  1               Request valid
        m_axis_data_dma_read_desc_ready     in   1               Request ready
        ==================================  ===  ==============  ===================

.. object:: s_axis_data_dma_read_desc_status
    
    DMA read descriptor status input (data)

    .. table::

        ======================================  ===  =============  ===================
        Signal                                  Dir  Width          Description
        ======================================  ===  =============  ===================
        s_axis_data_dma_read_desc_status_tag    in   DMA_TAG_WIDTH  Status tag
        s_axis_data_dma_read_desc_status_error  in   4              Status error code
        s_axis_data_dma_read_desc_status_valid  in   1              Status valid
        ======================================  ===  =============  ===================

.. object:: m_axis_data_dma_write_desc
    
    DMA write descriptor output (data)

    .. table::

        ===================================  ===  ==============  ===================
        Signal                               Dir  Width           Description
        ===================================  ===  ==============  ===================
        m_axis_data_dma_write_desc_dma_addr  out  DMA_ADDR_WIDTH  DMA address
        m_axis_data_dma_write_desc_ram_sel   out  RAM_SEL_WIDTH   RAM select
        m_axis_data_dma_write_desc_ram_addr  out  RAM_ADDR_WIDTH  RAM address
        m_axis_data_dma_write_desc_imm       out  DMA_IMM_WIDTH   Immediate
        m_axis_data_dma_write_desc_imm_en    out  1               Immediate enable
        m_axis_data_dma_write_desc_len       out  DMA_LEN_WIDTH   Transfer length
        m_axis_data_dma_write_desc_tag       out  DMA_TAG_WIDTH   Transfer tag
        m_axis_data_dma_write_desc_valid     out  1               Request valid
        m_axis_data_dma_write_desc_ready     in   1               Request ready
        ===================================  ===  ==============  ===================

.. object:: s_axis_data_dma_write_desc_status

    DMA write descriptor status input (data)

    .. table::

        =======================================  ===  =============  ===================
        Signal                                   Dir  Width          Description
        =======================================  ===  =============  ===================
        s_axis_data_dma_write_desc_status_tag    in   DMA_TAG_WIDTH  Status tag
        s_axis_data_dma_write_desc_status_error  in   4              Status error code
        s_axis_data_dma_write_desc_status_valid  in   1              Status valid
        =======================================  ===  =============  ===================

.. object:: ctrl_dma_ram

    DMA RAM interface (control)

    .. table::

        ==========================  ===  ================================  ===================
        Signal                      Dir  Width                             Description
        ==========================  ===  ================================  ===================
        ctrl_dma_ram_wr_cmd_sel     in   RAM_SEG_COUNT*RAM_SEL_WIDTH       Write command select
        ctrl_dma_ram_wr_cmd_be      in   RAM_SEG_COUNT*RAM_SEG_BE_WIDTH    Write command byte enable
        ctrl_dma_ram_wr_cmd_addr    in   RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH  Write command address
        ctrl_dma_ram_wr_cmd_data    in   RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH  Write command data
        ctrl_dma_ram_wr_cmd_valid   in   RAM_SEG_COUNT                     Write command valid
        ctrl_dma_ram_wr_cmd_ready   out  RAM_SEG_COUNT                     Write command ready
        ctrl_dma_ram_wr_done        out  RAM_SEG_COUNT                     Write done
        ctrl_dma_ram_rd_cmd_sel     in   RAM_SEG_COUNT*RAM_SEL_WIDTH       Read command select
        ctrl_dma_ram_rd_cmd_addr    in   RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH  Read command address
        ctrl_dma_ram_rd_cmd_valid   in   RAM_SEG_COUNT                     Read command valid
        ctrl_dma_ram_rd_cmd_ready   out  RAM_SEG_COUNT                     Read command ready
        ctrl_dma_ram_rd_resp_data   out  RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH  Read response data
        ctrl_dma_ram_rd_resp_valid  out  RAM_SEG_COUNT                     Read response valid
        ctrl_dma_ram_rd_resp_ready  in   RAM_SEG_COUNT                     Read response ready
        ==========================  ===  ================================  ===================

.. object:: data_dma_ram

    DMA RAM interface (data)

    .. table::

        ==========================  ===  ================================  ===================
        Signal                      Dir  Width                             Description
        ==========================  ===  ================================  ===================
        data_dma_ram_wr_cmd_sel     in   RAM_SEG_COUNT*RAM_SEL_WIDTH       Write command select
        data_dma_ram_wr_cmd_be      in   RAM_SEG_COUNT*RAM_SEG_BE_WIDTH    Write command byte enable
        data_dma_ram_wr_cmd_addr    in   RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH  Write command address
        data_dma_ram_wr_cmd_data    in   RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH  Write command data
        data_dma_ram_wr_cmd_valid   in   RAM_SEG_COUNT                     Write command valid
        data_dma_ram_wr_cmd_ready   out  RAM_SEG_COUNT                     Write command ready
        data_dma_ram_wr_done        out  RAM_SEG_COUNT                     Write done
        data_dma_ram_rd_cmd_sel     in   RAM_SEG_COUNT*RAM_SEL_WIDTH       Read command select
        data_dma_ram_rd_cmd_addr    in   RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH  Read command address
        data_dma_ram_rd_cmd_valid   in   RAM_SEG_COUNT                     Read command valid
        data_dma_ram_rd_cmd_ready   out  RAM_SEG_COUNT                     Read command ready
        data_dma_ram_rd_resp_data   out  RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH  Read response data
        data_dma_ram_rd_resp_valid  out  RAM_SEG_COUNT                     Read response valid
        data_dma_ram_rd_resp_ready  in   RAM_SEG_COUNT                     Read response ready
        ==========================  ===  ================================  ===================

.. object:: ptp

    PTP clock connections.

    .. table::

        =================  ===  ================  ===================
        Signal             Dir  Width             Description
        =================  ===  ================  ===================
        ptp_clk            in   1                 PTP clock
        ptp_rst            in   1                 PTP reset
        ptp_sample_clk     in   1                 PTP sample clock
        ptp_pps            in   1                 PTP pulse-per-second (synchronous to ptp_clk)
        ptp_ts_96          in   PTP_TS_WIDTH      current PTP time (synchronous to ptp_clk)
        ptp_ts_step        in   1                 PTP clock step (synchronous to ptp_clk)
        ptp_sync_pps       in   1                 PTP pulse-per-second (synchronous to clk)
        ptp_sync_ts_96     in   PTP_TS_WIDTH      current PTP time (synchronous to clk)
        ptp_sync_ts_step   in   1                 PTP clock step (synchronous to clk)
        ptp_perout_locked  in   PTP_PEROUT_COUNT  PTP period output locked
        ptp_perout_error   in   PTP_PEROUT_COUNT  PTP period output error
        ptp_perout_pulse   in   PTP_PEROUT_COUNT  PTP period output pulse
        =================  ===  ================  ===================

.. object:: direct_tx_clk

    Transmit clocks for direct asynchronous streaming interfaces, one per port

    .. table::

        =============  ===  ==========  ==================
        Signal         Dir  Width       Description
        =============  ===  ==========  ==================
        direct_tx_clk  in   PORT_COUNT  Transmit clock
        =============  ===  ==========  ==================

.. object:: direct_tx_rst

    Transmit resets for direct asynchronous streaming interfaces, one per port

    .. table::

        =============  ===  ==========  ==================
        Signal         Dir  Width       Description
        =============  ===  ==========  ==================
        direct_tx_rst  in   PORT_COUNT  Transmit reset
        =============  ===  ==========  ==================

.. object:: s_axis_direct_tx

    Streaming transmit data from host, one AXI stream interface per port.  Lowest latency interface, synchronous with transmit clock.

    .. table::

        =======================  ===  =============================  ==================
        Signal                   Dir  Width                          Description
        =======================  ===  =============================  ==================
        s_axis_direct_tx_tdata   in   PORT_COUNT*AXIS_DATA_WIDTH     Streaming data
        s_axis_direct_tx_tkeep   in   PORT_COUNT*AXIS_KEEP_WIDTH     Byte enable
        s_axis_direct_tx_tvalid  in   PORT_COUNT                     Data valid
        s_axis_direct_tx_tready  out  PORT_COUNT                     Ready for data
        s_axis_direct_tx_tlast   in   PORT_COUNT                     End of frame
        s_axis_direct_tx_tuser   in   PORT_COUNT*AXIS_TX_USER_WIDTH  Sideband data
        =======================  ===  =============================  ==================

    ``s_axis_direct_tx_tuser`` bits, per port

    .. table::

        ===============  =========  =============  =============
        Bit              Name       Width          Description
        ===============  =========  =============  =============
        0                bad_frame  1              Invalid frame
        TX_TAG_WIDTH:1   tx_tag     TX_TAG_WIDTH   Transmit tag
        ===============  =========  =============  =============

.. object:: m_axis_direct_tx

    Streaming transmit data towards network, one AXI stream interface per port.  Lowest latency interface, synchronous with transmit clock.

    .. table::

        =======================  ===  =============================  ==================
        Signal                   Dir  Width                          Description
        =======================  ===  =============================  ==================
        m_axis_direct_tx_tdata   out  PORT_COUNT*AXIS_DATA_WIDTH     Streaming data
        m_axis_direct_tx_tkeep   out  PORT_COUNT*AXIS_KEEP_WIDTH     Byte enable
        m_axis_direct_tx_tvalid  out  PORT_COUNT                     Data valid
        m_axis_direct_tx_tready  in   PORT_COUNT                     Ready for data
        m_axis_direct_tx_tlast   out  PORT_COUNT                     End of frame
        m_axis_direct_tx_tuser   out  PORT_COUNT*AXIS_TX_USER_WIDTH  Sideband data
        =======================  ===  =============================  ==================

    ``m_axis_direct_tx_tuser`` bits, per port

    .. table::

        ===============  =========  =============  =============
        Bit              Name       Width          Description
        ===============  =========  =============  =============
        0                bad_frame  1              Invalid frame
        TX_TAG_WIDTH:1   tx_tag     TX_TAG_WIDTH   Transmit tag
        ===============  =========  =============  =============

.. object:: s_axis_direct_tx_cpl

    Transmit PTP timestamp from MAC, one AXI stream interface per port.

    .. table::

        =============================  ===  ========================  ===================
        Signal                         Dir  Width                     Description
        =============================  ===  ========================  ===================
        s_axis_direct_tx_cpl_ts        in   PORT_COUNT*PTP_TS_WIDTH   PTP timestamp
        s_axis_direct_tx_cpl_tag       in   PORT_COUNT*TX_TAG_WIDTH   Transmit tag
        s_axis_direct_tx_cpl_valid     in   PORT_COUNT                Transmit completion valid
        s_axis_direct_tx_cpl_ready     out  PORT_COUNT                Transmit completion ready
        =============================  ===  ========================  ===================

.. object:: m_axis_direct_tx_cpl

    Transmit PTP timestamp towards core logic, one AXI stream interface per port.

    .. table::

        =============================  ===  ========================  ===================
        Signal                         Dir  Width                     Description
        =============================  ===  ========================  ===================
        s_axis_direct_tx_cpl_ts        out  PORT_COUNT*PTP_TS_WIDTH   PTP timestamp
        s_axis_direct_tx_cpl_tag       out  PORT_COUNT*TX_TAG_WIDTH   Transmit tag
        s_axis_direct_tx_cpl_valid     out  PORT_COUNT                Transmit completion valid
        s_axis_direct_tx_cpl_ready     in   PORT_COUNT                Transmit completion ready
        =============================  ===  ========================  ===================

.. object:: direct_rx_clk

    Receive clocks for direct asynchronous streaming interfaces, one per port

    .. table::

        =============  ===  ==========  ==================
        Signal         Dir  Width       Description
        =============  ===  ==========  ==================
        direct_rx_clk  in   PORT_COUNT  Receive clock
        =============  ===  ==========  ==================

.. object:: direct_rx_rst

    Receive resets for direct asynchronous streaming interfaces, one per port

    .. table::

        =============  ===  ==========  ==================
        Signal         Dir  Width       Description
        =============  ===  ==========  ==================
        direct_rx_rst  in   PORT_COUNT  Receive reset
        =============  ===  ==========  ==================

.. object:: s_axis_direct_rx

    Streaming receive data from network, one AXI stream interface per port.  Lowest latency interface, synchronous with receive clock.

    .. table::

        =======================  ===  =============================  ==================
        Signal                   Dir  Width                          Description
        =======================  ===  =============================  ==================
        s_axis_direct_rx_tdata   in   PORT_COUNT*AXIS_DATA_WIDTH     Streaming data
        s_axis_direct_rx_tkeep   in   PORT_COUNT*AXIS_KEEP_WIDTH     Byte enable
        s_axis_direct_rx_tvalid  in   PORT_COUNT                     Data valid
        s_axis_direct_rx_tready  out  PORT_COUNT                     Ready for data
        s_axis_direct_rx_tlast   in   PORT_COUNT                     End of frame
        s_axis_direct_rx_tuser   in   PORT_COUNT*AXIS_RX_USER_WIDTH  Sideband data
        =======================  ===  =============================  ==================

    ``s_axis_direct_rx_tuser`` bits, per port

    .. table::

        ===============  =========  =============  =============
        Bit              Name       Width          Description
        ===============  =========  =============  =============
        0                bad_frame  1              Invalid frame
        PTP_TS_WIDTH:1   ptp_ts     PTP_TS_WIDTH   PTP timestamp
        ===============  =========  =============  =============

.. object:: m_axis_direct_rx

    Streaming receive data towards host, one AXI stream interface per port.  Lowest latency interface, synchronous with receive clock.

    .. table::

        =======================  ===  =============================  ==================
        Signal                   Dir  Width                          Description
        =======================  ===  =============================  ==================
        m_axis_direct_rx_tdata   out  PORT_COUNT*AXIS_DATA_WIDTH     Streaming data
        m_axis_direct_rx_tkeep   out  PORT_COUNT*AXIS_KEEP_WIDTH     Byte enable
        m_axis_direct_rx_tvalid  out  PORT_COUNT                     Data valid
        m_axis_direct_rx_tready  in   PORT_COUNT                     Ready for data
        m_axis_direct_rx_tlast   out  PORT_COUNT                     End of frame
        m_axis_direct_rx_tuser   out  PORT_COUNT*AXIS_RX_USER_WIDTH  Sideband data
        =======================  ===  =============================  ==================

    ``m_axis_direct_rx_tuser`` bits, per port

    .. table::

        ===============  =========  =============  =============
        Bit              Name       Width          Description
        ===============  =========  =============  =============
        0                bad_frame  1              Invalid frame
        PTP_TS_WIDTH:1   ptp_ts     PTP_TS_WIDTH   PTP timestamp
        ===============  =========  =============  =============

.. object:: s_axis_sync_tx

    Streaming transmit data from host, one AXI stream interface per port.  Low latency interface, synchronous with core clock.

    .. table::

        =====================  ===  ==================================  ==================
        Signal                 Dir  Width                               Description
        =====================  ===  ==================================  ==================
        s_axis_sync_tx_tdata   in   PORT_COUNT*AXIS_SYNC_DATA_WIDTH     Streaming data
        s_axis_sync_tx_tkeep   in   PORT_COUNT*AXIS_SYNC_KEEP_WIDTH     Byte enable
        s_axis_sync_tx_tvalid  in   PORT_COUNT                          Data valid
        s_axis_sync_tx_tready  out  PORT_COUNT                          Ready for data
        s_axis_sync_tx_tlast   in   PORT_COUNT                          End of frame
        s_axis_sync_tx_tuser   in   PORT_COUNT*AXIS_SYNC_TX_USER_WIDTH  Sideband data
        =====================  ===  ==================================  ==================

    ``s_axis_sync_tx_tuser`` bits, per port

    .. table::

        ===============  =========  =============  =============
        Bit              Name       Width          Description
        ===============  =========  =============  =============
        0                bad_frame  1              Invalid frame
        TX_TAG_WIDTH:1   tx_tag     TX_TAG_WIDTH   Transmit tag
        ===============  =========  =============  =============

.. object:: m_axis_sync_tx

    Streaming transmit data towards network, one AXI stream interface per port.  Low latency interface, synchronous with core clock.

    .. table::

        =====================  ===  ==================================  ==================
        Signal                 Dir  Width                               Description
        =====================  ===  ==================================  ==================
        m_axis_sync_tx_tdata   out  PORT_COUNT*AXIS_SYNC_DATA_WIDTH     Streaming data
        m_axis_sync_tx_tkeep   out  PORT_COUNT*AXIS_SYNC_KEEP_WIDTH     Byte enable
        m_axis_sync_tx_tvalid  out  PORT_COUNT                          Data valid
        m_axis_sync_tx_tready  in   PORT_COUNT                          Ready for data
        m_axis_sync_tx_tlast   out  PORT_COUNT                          End of frame
        m_axis_sync_tx_tuser   out  PORT_COUNT*AXIS_SYNC_TX_USER_WIDTH  Sideband data
        =====================  ===  ==================================  ==================

    ``m_axis_sync_tx_tuser`` bits, per port

    .. table::

        ===============  =========  =============  =============
        Bit              Name       Width          Description
        ===============  =========  =============  =============
        0                bad_frame  1              Invalid frame
        TX_TAG_WIDTH:1   tx_tag     TX_TAG_WIDTH   Transmit tag
        ===============  =========  =============  =============

.. object:: s_axis_sync_tx_cpl

    Transmit PTP timestamp from MAC, one AXI stream interface per port.

    .. table::

        ===========================  ===  ========================  ===================
        Signal                       Dir  Width                     Description
        ===========================  ===  ========================  ===================
        s_axis_sync_tx_cpl_ts        in   PORT_COUNT*PTP_TS_WIDTH   PTP timestamp
        s_axis_sync_tx_cpl_tag       in   PORT_COUNT*TX_TAG_WIDTH   Transmit tag
        s_axis_sync_tx_cpl_valid     in   PORT_COUNT                Transmit completion valid
        s_axis_sync_tx_cpl_ready     out  PORT_COUNT                Transmit completion ready
        ===========================  ===  ========================  ===================

.. object:: m_axis_sync_tx_cpl

    Transmit PTP timestamp towards core logic, one AXI stream interface per port.

    .. table::

        ===========================  ===  ========================  ===================
        Signal                       Dir  Width                     Description
        ===========================  ===  ========================  ===================
        s_axis_sync_tx_cpl_ts        out  PORT_COUNT*PTP_TS_WIDTH   PTP timestamp
        s_axis_sync_tx_cpl_tag       out  PORT_COUNT*TX_TAG_WIDTH   Transmit tag
        s_axis_sync_tx_cpl_valid     out  PORT_COUNT                Transmit completion valid
        s_axis_sync_tx_cpl_ready     in   PORT_COUNT                Transmit completion ready
        ===========================  ===  ========================  ===================

.. object:: s_axis_sync_rx

    Streaming receive data from network, one AXI stream interface per port.  Low latency interface, synchronous with core clock.

    .. table::

        =====================  ===  ==================================  ==================
        Signal                 Dir  Width                               Description
        =====================  ===  ==================================  ==================
        s_axis_sync_rx_tdata   in   PORT_COUNT*AXIS_SYNC_DATA_WIDTH     Streaming data
        s_axis_sync_rx_tkeep   in   PORT_COUNT*AXIS_SYNC_KEEP_WIDTH     Byte enable
        s_axis_sync_rx_tvalid  in   PORT_COUNT                          Data valid
        s_axis_sync_rx_tready  out  PORT_COUNT                          Ready for data
        s_axis_sync_rx_tlast   in   PORT_COUNT                          End of frame
        s_axis_sync_rx_tuser   in   PORT_COUNT*AXIS_SYNC_RX_USER_WIDTH  Sideband data
        =====================  ===  ==================================  ==================

    ``s_axis_sync_rx_tuser`` bits, per port

    .. table::

        ===============  =========  =============  =============
        Bit              Name       Width          Description
        ===============  =========  =============  =============
        0                bad_frame  1              Invalid frame
        PTP_TS_WIDTH:1   ptp_ts     PTP_TS_WIDTH   PTP timestamp
        ===============  =========  =============  =============

.. object:: m_axis_sync_rx

    Streaming receive data towards host, one AXI stream interface per port.  Low latency interface, synchronous with core clock.

    .. table::

        =====================  ===  ==================================  ==================
        Signal                 Dir  Width                               Description
        =====================  ===  ==================================  ==================
        m_axis_sync_rx_tdata   out  PORT_COUNT*AXIS_SYNC_DATA_WIDTH     Streaming data
        m_axis_sync_rx_tkeep   out  PORT_COUNT*AXIS_SYNC_KEEP_WIDTH     Byte enable
        m_axis_sync_rx_tvalid  out  PORT_COUNT                          Data valid
        m_axis_sync_rx_tready  in   PORT_COUNT                          Ready for data
        m_axis_sync_rx_tlast   out  PORT_COUNT                          End of frame
        m_axis_sync_rx_tuser   out  PORT_COUNT*AXIS_SYNC_RX_USER_WIDTH  Sideband data
        =====================  ===  ==================================  ==================

    ``m_axis_sync_rx_tuser`` bits, per port

    .. table::

        ===============  =========  =============  =============
        Bit              Name       Width          Description
        ===============  =========  =============  =============
        0                bad_frame  1              Invalid frame
        PTP_TS_WIDTH:1   ptp_ts     PTP_TS_WIDTH   PTP timestamp
        ===============  =========  =============  =============

.. object:: s_axis_if_tx

    Streaming transmit data from host, one AXI stream interface per interface.  Closest interface to host, synchronous with core clock.

    .. table::

        ===================  ===  ================================  ==================
        Signal               Dir  Width                             Description
        ===================  ===  ================================  ==================
        s_axis_if_tx_tdata   in   PORT_COUNT*AXIS_IF_DATA_WIDTH     Streaming data
        s_axis_if_tx_tkeep   in   PORT_COUNT*AXIS_IF_KEEP_WIDTH     Byte enable
        s_axis_if_tx_tvalid  in   PORT_COUNT                        Data valid
        s_axis_if_tx_tready  out  PORT_COUNT                        Ready for data
        s_axis_if_tx_tlast   in   PORT_COUNT                        End of frame
        s_axis_if_tx_tid     in   PORT_COUNT*AXIS_IF_TX_ID_WIDTH    Source queue
        s_axis_if_tx_tdest   in   PORT_COUNT*AXIS_IF_TX_DEST_WIDTH  Destination port
        s_axis_if_tx_tuser   in   PORT_COUNT*AXIS_IF_TX_USER_WIDTH  Sideband data
        ===================  ===  ================================  ==================

    ``s_axis_if_tx_tuser`` bits, per interface

    .. table::

        ===============  =========  =============  =============
        Bit              Name       Width          Description
        ===============  =========  =============  =============
        0                bad_frame  1              Invalid frame
        TX_TAG_WIDTH:1   tx_tag     TX_TAG_WIDTH   Transmit tag
        ===============  =========  =============  =============

.. object:: m_axis_if_tx

    Streaming transmit data towards network, one AXI stream interface per interface.  Closest interface to host, synchronous with core clock.

    .. table::

        ===================  ===  ================================  ==================
        Signal               Dir  Width                             Description
        ===================  ===  ================================  ==================
        m_axis_if_tx_tdata   out  PORT_COUNT*AXIS_IF_DATA_WIDTH     Streaming data
        m_axis_if_tx_tkeep   out  PORT_COUNT*AXIS_IF_KEEP_WIDTH     Byte enable
        m_axis_if_tx_tvalid  out  PORT_COUNT                        Data valid
        m_axis_if_tx_tready  in   PORT_COUNT                        Ready for data
        m_axis_if_tx_tlast   out  PORT_COUNT                        End of frame
        m_axis_if_tx_tid     out  PORT_COUNT*AXIS_IF_TX_ID_WIDTH    Source queue
        m_axis_if_tx_tdest   out  PORT_COUNT*AXIS_IF_TX_DEST_WIDTH  Destination port
        m_axis_if_tx_tuser   out  PORT_COUNT*AXIS_IF_TX_USER_WIDTH  Sideband data
        ===================  ===  ================================  ==================

    ``m_axis_if_tx_tuser`` bits, per interface

    .. table::

        ===============  =========  =============  =============
        Bit              Name       Width          Description
        ===============  =========  =============  =============
        0                bad_frame  1              Invalid frame
        TX_TAG_WIDTH:1   tx_tag     TX_TAG_WIDTH   Transmit tag
        ===============  =========  =============  =============

.. object:: s_axis_if_tx_cpl

    Transmit PTP timestamp from MAC, one AXI stream interface per interface.

    .. table::

        =========================  ===  ========================  ===================
        Signal                     Dir  Width                     Description
        =========================  ===  ========================  ===================
        s_axis_if_tx_cpl_ts        in   PORT_COUNT*PTP_TS_WIDTH   PTP timestamp
        s_axis_if_tx_cpl_tag       in   PORT_COUNT*TX_TAG_WIDTH   Transmit tag
        s_axis_if_tx_cpl_valid     in   PORT_COUNT                Transmit completion valid
        s_axis_if_tx_cpl_ready     out  PORT_COUNT                Transmit completion ready
        =========================  ===  ========================  ===================

.. object:: m_axis_if_tx_cpl

    Transmit PTP timestamp towards core logic, one AXI stream interface per interface.

    .. table::

        =========================  ===  ========================  ===================
        Signal                     Dir  Width                     Description
        =========================  ===  ========================  ===================
        s_axis_if_tx_cpl_ts        out  PORT_COUNT*PTP_TS_WIDTH   PTP timestamp
        s_axis_if_tx_cpl_tag       out  PORT_COUNT*TX_TAG_WIDTH   Transmit tag
        s_axis_if_tx_cpl_valid     out  PORT_COUNT                Transmit completion valid
        s_axis_if_tx_cpl_ready     in   PORT_COUNT                Transmit completion ready
        =========================  ===  ========================  ===================

.. object:: s_axis_if_rx

    Streaming receive data from network, one AXI stream interface per interface.  Closest interface to host, synchronous with core clock.

    .. table::

        ===================  ===  ================================  ==================
        Signal               Dir  Width                             Description
        ===================  ===  ================================  ==================
        s_axis_if_rx_tdata   in   PORT_COUNT*AXIS_IF_DATA_WIDTH     Streaming data
        s_axis_if_rx_tkeep   in   PORT_COUNT*AXIS_IF_KEEP_WIDTH     Byte enable
        s_axis_if_rx_tvalid  in   PORT_COUNT                        Data valid
        s_axis_if_rx_tready  out  PORT_COUNT                        Ready for data
        s_axis_if_rx_tlast   in   PORT_COUNT                        End of frame
        s_axis_if_rx_tid     in   PORT_COUNT*AXIS_IF_RX_ID_WIDTH    Source port
        s_axis_if_rx_tdest   in   PORT_COUNT*AXIS_IF_RX_DEST_WIDTH  Destination queue
        s_axis_if_rx_tuser   in   PORT_COUNT*AXIS_IF_RX_USER_WIDTH  Sideband data
        ===================  ===  ================================  ==================

    ``s_axis_if_rx_tuser`` bits, per interface

    .. table::

        ===============  =========  =============  =============
        Bit              Name       Width          Description
        ===============  =========  =============  =============
        0                bad_frame  1              Invalid frame
        PTP_TS_WIDTH:1   ptp_ts     PTP_TS_WIDTH   PTP timestamp
        ===============  =========  =============  =============

.. object:: m_axis_if_rx

    Streaming receive data towards host, one AXI stream interface per interface.  Closest interface to host, synchronous with core clock.

    .. table::

        ===================  ===  ================================  ==================
        Signal               Dir  Width                             Description
        ===================  ===  ================================  ==================
        m_axis_if_rx_tdata   out  PORT_COUNT*AXIS_IF_DATA_WIDTH     Streaming data
        m_axis_if_rx_tkeep   out  PORT_COUNT*AXIS_IF_KEEP_WIDTH     Byte enable
        m_axis_if_rx_tvalid  out  PORT_COUNT                        Data valid
        m_axis_if_rx_tready  in   PORT_COUNT                        Ready for data
        m_axis_if_rx_tlast   out  PORT_COUNT                        End of frame
        m_axis_if_rx_tid     out  PORT_COUNT*AXIS_IF_RX_ID_WIDTH    Source port
        m_axis_if_rx_tdest   out  PORT_COUNT*AXIS_IF_RX_DEST_WIDTH  Destination queue
        m_axis_if_rx_tuser   out  PORT_COUNT*AXIS_IF_RX_USER_WIDTH  Sideband data
        ===================  ===  ================================  ==================

    ``m_axis_if_rx_tuser`` bits, per interface

    .. table::

        ===============  =========  =============  =============
        Bit              Name       Width          Description
        ===============  =========  =============  =============
        0                bad_frame  1              Invalid frame
        PTP_TS_WIDTH:1   ptp_ts     PTP_TS_WIDTH   PTP timestamp
        ===============  =========  =============  =============

.. object:: m_axis_stat

    Statistics increment output

    .. table::

        ==================  ===  ==============  ===================
        Signal              Dir  Width           Description
        ==================  ===  ==============  ===================
        m_axis_stat_tdata   in   STAT_INC_WIDTH  Statistic increment
        m_axis_stat_tid     in   STAT_ID_WIDTH   Statistic ID
        m_axis_stat_tvalid  in   1               Statistic valid
        m_axis_stat_tready  out  1               Statistic ready
        ==================  ===  ==============  ===================

.. object:: gpio

    Application section GPIO

    .. table::

        ========  ===  ==================  ===================
        Signal    Dir  Width               Description
        ========  ===  ==================  ===================
        gpio_in   in   APP_GPIO_IN_WIDTH   GPIO inputs
        gpio_out  out  APP_GPIO_OUT_WIDTH  GPIO outputs
        ========  ===  ==================  ===================

.. object:: jtag

    Application section JTAG scan chain

    .. table::

        ========  ===  =====  ===================
        Signal    Dir  Width  Description
        ========  ===  =====  ===================
        jtag_tdi  in   1      JTAG TDI
        jtag_tdo  out  1      JTAG TDO
        jtag_tms  in   1      JTAG TMS
        jtag_tck  in   1      JTAG TCK
        ========  ===  =====  ===================
