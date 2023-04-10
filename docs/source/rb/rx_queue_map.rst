.. _rb_rx_queue_map:

===========================
RX queue map register block
===========================

The RX queue map register block has a header with type 0x0000C090, version 0x00000200, and is used to control the mapping of packets into RX queues.

.. table::

    ============  =============  ======  ======  ======  ======  =============
    Address       Field          31..24  23..16  15..8   7..0    Reset value
    ============  =============  ======  ======  ======  ======  =============
    RBB+0x00      Type           Vendor ID       Type            RO 0x0000C090
    ------------  -------------  --------------  --------------  -------------
    RBB+0x04      Version        Major   Minor   Patch   Meta    RO 0x00000200
    ------------  -------------  ------  ------  ------  ------  -------------
    RBB+0x08      Next pointer   Pointer to next register block  RO -
    ------------  -------------  ------------------------------  -------------
    RBB+0x0C      Config                         Tbl sz  Ports   RO -
    ------------  -------------  ------  ------  ------  ------  -------------
    RBB+0x10+16n  Port offset    Port indirection table offset   RO -
    ------------  -------------  ------------------------------  -------------
    RBB+0x14+16n  Port RSS mask  Port RSS mask                   RW 0x00000000
    ------------  -------------  ------------------------------  -------------
    RBB+0x18+16n  Port app mask  Port app mask                   RW 0x00000000
    ============  =============  ==============================  =============

See :ref:`rb_overview` for definitions of the standard register block header fields.

There is one set of registers per port, with the source port for each packet determined by the ``tid`` field, which is set in the RX FIFO subsystem to identify the source port when data is aggregated from multiple ports.  For each packet, the ``tdest`` field (provided by custom logic in the application section) and flow hash (computed in :ref:`mod_rx_hash` in :ref:`mod_mqnic_ingress`) are combined according to::

    if (app_direct_enable[tid] && tdest[DEST_WIDTH-1]) begin
        queue_index = tdest;
    end else begin
        queue_index = indir_table[tid][(tdest & app_mask[tid]) + (rss_hash & rss_mask[tid])];
    end

The goal of this setup is to enable any combination of flow hashing and custom application logic to influence queue selection, under the direction of host software.

.. object:: Config

    The port count field contains information about the queue mapping configuration.  The ports field contains the number of ports, while the table size field contains the log of the number of entries in the indirection table.

    .. table::

        ========  ======  ======  ======  ======  =============
        Address   31..24  23..16  15..8   7..0    Reset value
        ========  ======  ======  ======  ======  =============
        RBB+0x0C                  Tbl sz  Ports   RO -
        ========  ======  ======  ======  ======  =============

.. object:: Port indirection table offset

    The port indirection table offset field contains the offset to the start of the indirection table region, relative to the start of the current region.  The indirection table itself is an array of 32-bit words, which should be loaded with the

    .. table::

        ============  ======  ======  ======  ======  =============
        Address       31..24  23..16  15..8   7..0    Reset value
        ============  ======  ======  ======  ======  =============
        RBB+0x10+16n  Port indirection table offset   RO -
        ============  ==============================  =============

.. object:: Port RSS mask

    The port RSS mask field contains a mask value to select a portion of the RSS flow hash.

    .. table::

        ============  ======  ======  ======  ======  =============
        Address       31..24  23..16  15..8   7..0    Reset value
        ============  ======  ======  ======  ======  =============
        RBB+0x14+16n  Port RSS mask                   RW 0x00000000
        ============  ==============================  =============

.. object:: Port app mask

    The port app mask field contains a mask value to select a portion of the application-provided ``tdest`` value.  Bit 31 of this register controls the application section's ability to directly select a destination queue.  If bit 31 is set, the application section can set the MSB of ``tdest`` to pass through the rest of ``tdest`` without modification.

    .. table::

        ============  ======  ======  ======  ======  =============
        Address       31..24  23..16  15..8   7..0    Reset value
        ============  ======  ======  ======  ======  =============
        RBB+0x18+16n  Port app mask                   RW 0x00000000
        ============  ==============================  =============
