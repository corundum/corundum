.. _mod_tx_engine:

=============
``tx_engine``
=============

``tx_engine`` manages transmit datapath operations including descriptor dequeue and fetch via DMA, packet data fetch via DMA, packet transmission, and completion enqueue and writeback via DMA.  It also handles PTP timestamps for inclusion in completion records.
