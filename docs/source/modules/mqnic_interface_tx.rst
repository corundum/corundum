.. _mod_mqnic_interface_tx:

======================
``mqnic_interface_tx``
======================

``mqnic_interface_tx`` implements the host-side transmit datapath.

``mqnic_interface_tx`` integrates the following modules:

* :ref:`mod_tx_engine`: transmit engine
* ``dma_client_axis_source``: internal DMA engine
* :ref:`mod_mqnic_egress`: egress datapath
