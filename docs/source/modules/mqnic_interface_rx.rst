.. _mod_mqnic_interface_rx:

======================
``mqnic_interface_rx``
======================

``mqnic_interface_rx`` implements the host-side receive datapath.

``mqnic_interface_rx`` integrates the following modules:

* :ref:`mod_rx_engine`: receive engine
* :ref:`mod_mqnic_ingress`: ingress datapath
* ``dma_client_axis_sink``: internal DMA engine
