.. _mod_mqnic_interface:

===================
``mqnic_interface``
===================

``mqnic_interface`` implements one NIC interface, including the queue management logic, descriptor, completion, and event handling, transmit scheduler, and the transmit and receive datapaths.

``mqnic_interface`` integrates the following modules:

* :ref:`mod_queue_manager`: transmit and receive queues
* :ref:`mod_cpl_queue_manager`: transmit and receive completion queues, event queues
* :ref:`mod_desc_fetch`: descriptor fetch
* :ref:`mod_cpl_write`: completion write
* :ref:`mod_mqnic_tx_scheduler_block`: transmit scheduler
* :ref:`mod_mqnic_interface_rx`: receive datapath
* :ref:`mod_mqnic_interface_tx`: transmit datapath
