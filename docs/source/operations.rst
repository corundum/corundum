.. _operations:

==========
Operations
==========

This is a list of all of the operations involved in sending and receiving packets, across both hardware and software.

Packet transmission
===================

#. linux: The linux kernel calls ``mqnic_start_xmit()`` (via ``ndo_start_xmit()``) with an ``sk_buff`` for transmission
#. ``mqnic_start_xmit()`` (``mqnic_tx.c``): The driver determines the destination transmit queue with ``skb_get_queue_mapping``
#. ``mqnic_start_xmit()`` (``mqnic_tx.c``): The driver marks the ``sk_buff`` for timestamping, if requested
#. ``mqnic_start_xmit()`` (``mqnic_tx.c``): The driver generates the hardware IP checksum command and writes it into the descriptor
#. ``mqnic_map_skb()`` (``mqnic_tx.c``): The driver writes a reference to the ``sk_buff`` into ``ring->tx_info``
#. ``mqnic_map_skb()`` (``mqnic_tx.c``): The driver generates DMA mappings for the ``sk_buff`` (``skb_frag_dma_map()``/``dma_map_single()``) and builds the descriptor
#. ``mqnic_start_xmit()`` (``mqnic_tx.c``): The driver enqueues the packet by incrementing its local copy of the producer pointer
#. ``mqnic_start_xmit()`` (``mqnic_tx.c``): At the end of a batch of packets, the driver writes the updated producer pointer to the NIC via MMIO
#. :ref:`mod_queue_manager` ``s_axil_*``: The MMIO write arrives at the queue manager via AXI lite
#. :ref:`mod_queue_manager` ``m_axis_doorbell_*``: The queue manager updates the producer pointer and generates a doorbell event
#. :ref:`mod_tx_scheduler_rr` ``s_axis_doorbell_*``: The doorbell event arrives at the port schedulers
#. :ref:`mod_tx_scheduler_rr`: The scheduler marks the queue as active and schedules it if necessary
#. :ref:`mod_tx_scheduler_rr`: The scheduler decides to send a packet
#. :ref:`mod_tx_scheduler_rr` ``m_axis_tx_req_*``: The scheduler generates a transmit request
#. :ref:`mod_tx_engine` ``s_axis_tx_req_*``: The transmit request arrives at the transmit engine
#. :ref:`mod_tx_engine` ``m_axis_desc_req_*``: The transmit engine issues a descriptor request
#. :ref:`mod_desc_fetch` ``s_axis_desc_req_*``: The descriptor request arrives at the descriptor fetch module
#. :ref:`mod_desc_fetch` ``m_axis_desc_dequeue_req_*``: The descriptor fetch module issues a dequeue request to the queue manager
#. :ref:`mod_queue_manager` ``s_axis_dequeue_req_*``: The dequeue request arrives at the queue manager module
#. :ref:`mod_queue_manager`: If the queue is not empty, the queue manager starts a dequeue operation on the queue
#. :ref:`mod_queue_manager` ``m_axis_dequeue_resp_*``: The queue manager sends a response containing the operation status and DMA address
#. :ref:`mod_desc_fetch` ``s_axis_desc_dequeue_resp_*``: The response arrives at the descriptor fetch module
#. :ref:`mod_desc_fetch` ``m_axis_req_status_*``: The descriptor module reports the descriptor fetch status
#. :ref:`mod_desc_fetch` ``m_axis_dma_read_desc_*``: The descriptor module issues a DMA read request
#. ``dma_if_pcie_rd`` ``s_axis_read_desc_*``: The requst arrives at the DMA read interface
#. ``dma_if_pcie_rd``: The DMA read interface issues a PCIe read request
#. ``dma_if_pcie_rd``: The read data comes back in a completion packet and is written to the descriptor fetch local DMA RAM
#. ``dma_if_pcie_rd`` ``m_axis_read_desc_status_*``: The DMA read interface issues a status message
#. :ref:`mod_desc_fetch` ``m_axis_desc_dequeue_commit_*``: The descriptor fetch module issues a dequeue commit message
#. :ref:`mod_queue_manager`: The queue manager commits the dequeue operation and updates the consumer pointer
#. :ref:`mod_desc_fetch` ``dma_read_desc_*``: The descriptor fetch module issues a read request to its internal DMA module
#. :ref:`mod_desc_fetch` ``m_axis_desc_*``: The internal DMA module reads the descriptor and transfers it via AXI stream
#. :ref:`mod_tx_engine`: The descriptor arrives at the transmit engine
#. :ref:`mod_tx_engine`: The transmit engine stores the descriptor data
#. :ref:`mod_tx_engine` ``m_axis_dma_read_desc_*``: The transmit engine issues a DMA read request
#. ``dma_if_pcie_rd`` ``s_axis_read_desc_*``: The requst arrives at the DMA read interface
#. ``dma_if_pcie_rd``: The DMA read interface issues a PCIe read request
#. ``dma_if_pcie_rd``: The read data comes back in a completion packet and is written to the interface local DMA RAM
#. ``dma_if_pcie_rd`` ``m_axis_read_desc_status_*``: The DMA read interface issues a status message
#. :ref:`mod_tx_engine` ``m_axis_tx_desc_*``: The transmit engine issues a read request to the interface DMA engine
#. :ref:`mod_tx_engine` ``m_axis_tx_csum_cmd_*``: The transmit engine issues a transmit checksum command
#. :ref:`mod_mqnic_interface_tx` ``tx_axis_*``: The interface DMA module reads the packet data from interface local DMA RAM and transfers it via AXI stream
#. :ref:`mod_mqnic_egress`: egress processing
#. :ref:`mod_tx_checksum`: The transmit checksum module computes and inserts the checksum
#. :ref:`mod_mqnic_app_block` ``s_axis_if_tx``: data is presented to the application section
#. :ref:`mod_mqnic_app_block` ``m_axis_if_tx``: data is returned from the application section
#. :ref:`mod_mqnic_core`: Data passes enters per-interface transmit FIFO module and is divided into per-port, per-traffic-class FIFOs
#. :ref:`mod_mqnic_app_block` ``s_axis_sync_tx``: data is presented to the application section
#. :ref:`mod_mqnic_app_block` ``m_axis_sync_tx``: data is returned from the application section
#. :ref:`mod_mqnic_core`: Data passes through per-port transmit async FIFO module and is transferred to MAC TX clock domain
#. :ref:`mod_mqnic_app_block` ``s_axis_direct_tx``: data is presented to the application section
#. :ref:`mod_mqnic_app_block` ``m_axis_direct_tx``: data is returned from the application section
#. :ref:`mod_mqnic_l2_egress`: layer 2 egress processing
#. :ref:`mod_mqnic_core`: data leaves through transmit streaming interfaces
#. The packet arrives at the MAC
#. The MAC produces a PTP timestamp
#. :ref:`mod_tx_engine`: The PTP timestamp arrives at the transmit engine
#. :ref:`mod_tx_engine` ``m_axis_cpl_req_*``: The transmit engine issues a completion write request
#. :ref:`mod_cpl_write`: The completion write module writes the completion data into its local DMA RAM
#. :ref:`mod_cpl_write` ``m_axis_cpl_enqueue_req_*``: The completion write module issues an enqueue request to the completion queue manager
#. :ref:`mod_cpl_queue_manager` ``m_axis_enqueue_req_*``: The enqueue request arrives at the completion queue manager module
#. :ref:`mod_cpl_queue_manager`: If the queue is not full, the queue manager starts an enqueue operation on the queue
#. :ref:`mod_cpl_queue_manager` ``m_axis_enqueue_resp_*``: The completion queue manager sends a response containing the operation status and DMA address
#. :ref:`mod_cpl_write`: The response arrives at the completion write module
#. :ref:`mod_cpl_write` ``m_axis_req_status_*``: The completion write module reports the completion write status
#. :ref:`mod_desc_fetch` ``m_axis_dma_write_desc_*``: The completion write module issues a DMA write request
#. ``dma_if_pcie_wr`` ``s_axis_write_desc_*``: The requst arrives at the DMA write interface
#. ``dma_if_pcie_wr``: The DMA write interface reads the completion data from the completion write module local DMA RAM
#. ``dma_if_pcie_wr``: The DMA write interface issues a PCIe write request
#. ``dma_if_pcie_wr`` ``m_axis_write_desc_status_*``: The DMA write interface issues a status message
#. :ref:`mod_cpl_write` ``m_axis_desc_enqueue_commit_*``: The completion write module issues an enqueue commit message
#. :ref:`mod_cpl_queue_manager`: The completion queue manager commits the enqueue operation and updates the producer pointer
#. :ref:`mod_cpl_queue_manager` ``m_axis_event_*``: The completion queue manager issues an event, if armed
#. :ref:`mod_cpl_write`: The event arrives at the completion write module
#. :ref:`mod_cpl_write`: The completion write module writes the event data into its local DMA RAM
#. :ref:`mod_cpl_write` ``m_axis_cpl_enqueue_req_*``: The completion write module issues an enqueue request to the completion queue manager
#. :ref:`mod_cpl_queue_manager` ``s_axis_enqueue_req_*``: The enqueue request arrives at the completion queue manager module
#. :ref:`mod_cpl_queue_manager`: If the queue is not full, the queue manager starts an enqueue operation on the queue
#. :ref:`mod_cpl_queue_manager` ``m_axis_enqueue_resp_*``: The completion queue manager sends a response containing the operation status and DMA address
#. :ref:`mod_cpl_write` ``s_axis_cpl_enqueue_resp_*``: The response arrives at the completion write module
#. :ref:`mod_cpl_write` ``m_axis_req_status_*``: The completion write module reports the completion write status
#. :ref:`mod_desc_fetch` ``m_axis_dma_write_desc_*``: The completion write module issues a DMA write request
#. ``dma_if_pcie_wr`` ``s_axis_write_desc_*``: The requst arrives at the DMA write interface
#. ``dma_if_pcie_wr``: The DMA write interface reads the event data from the completion write module local DMA RAM
#. ``dma_if_pcie_wr``: The DMA write interface issues a PCIe write request
#. ``dma_if_pcie_wr`` ``m_axis_write_desc_status_*``: The DMA write interface issues a status message
#. :ref:`mod_cpl_write` ``m_axis_desc_enqueue_commit_*``: The completion write module issues an enqueue commit message
#. :ref:`mod_cpl_queue_manager`: The completion queue manager commits the enqueue operation and updates the producer pointer
#. :ref:`mod_cpl_queue_manager` ``m_axis_event_*``: The completion queue manager issues an interrupt, if armed
#. linux: The linux kernel calls ``mqnic_irq_handler()``
#. ``mqnic_irq_handler()`` (``mqnic_irq.c``): The driver calls the EQ handler via the notifier chain (``atomic_notifier_call_chain()``)
#. ``mqnic_eq_int()`` (``mqnic_eq.c``): The driver calls ``mqnic_process_eq()``
#. ``mqnic_process_eq()`` (``mqnic_eq.c``): The driver processes the event queue, which calls the appropriate handler (``mqnic_tx_irq()``)
#. ``mqnic_tx_irq()`` (``mqnic_tx.c``): The driver enables NAPI polling on the queue (``napi_schedule_irqoff()``)
#. ``mqnic_eq_int()`` (``mqnic_eq.c``): The driver rearms the EQ (``mqnic_arm_eq()``)
#. NAPI: The linux kernel calls ``mqnic_poll_tx_cq()``
#. ``mqnic_poll_tx_cq()`` (``mqnic_tx.c``): The driver calls ``mqnic_process_tx_cq()``
#. ``mqnic_process_tx_cq()`` (``mqnic_tx.c``): The driver reads the completion queue producer pointer from the NIC
#. ``mqnic_process_tx_cq()`` (``mqnic_tx.c``): The driver reads the completion record
#. ``mqnic_process_tx_cq()`` (``mqnic_tx.c``): The driver reads the ``sk_buff`` from ``ring->tx_info``
#. ``mqnic_process_tx_cq()`` (``mqnic_tx.c``): The driver completes the transmit timestamp operation
#. ``mqnic_process_tx_cq()`` (``mqnic_tx.c``): The driver calls ``mqnic_free_tx_desc()``
#. ``mqnic_free_tx_desc()`` (``mqnic_tx.c``): The driver unmaps the ``sk_buff`` (``dma_unmap_single()``/``dma_unmap_page()``)
#. ``mqnic_free_tx_desc()`` (``mqnic_tx.c``): The driver frees the ``sk_buff`` (``napi_consume_skb()``)
#. ``mqnic_process_tx_cq()`` (``mqnic_tx.c``): The driver dequeues the completion record by incrementing the completion queue consumer pointer
#. ``mqnic_process_tx_cq()`` (``mqnic_tx.c``): The driver writes the updated consumer pointer via MMIO
#. ``mqnic_process_tx_cq()`` (``mqnic_tx.c``): The driver reads the queue consumer pointer from the NIC
#. ``mqnic_process_tx_cq()`` (``mqnic_tx.c``): The driver increments the ring consumer pointer for in-order freed descriptors
#. ``mqnic_process_tx_cq()`` (``mqnic_tx.c``): The driver wakes the queue if it was stopped (``netif_tx_wake_queue()``)
#. ``mqnic_poll_tx_cq()`` (``mqnic_tx.c``): The driver disables NAPI polling, when idle (``napi_complete()``)
#. ``mqnic_poll_tx_cq()`` (``mqnic_tx.c``): The driver rearms the CQ (``mqnic_arm_cq()``)

Packet reception
================

init:

#. ``mqnic_activate_rx_ring()`` (``mqnic_rx.c``): The driver calls ``mqnic_refill_rx_buffers()``
#. ``mqnic_refill_rx_buffers()`` (``mqnic_rx.c``): The driver calls ``mqnic_prepare_rx_desc()`` for each empty location in the ring
#. ``mqnic_prepare_rx_desc()`` (``mqnic_rx.c``): The driver allocates memory pages (``dev_alloc_pages()``)
#. ``mqnic_prepare_rx_desc()`` (``mqnic_rx.c``): The driver maps the pages (``dev_alloc_pages()``)
#. ``mqnic_prepare_rx_desc()`` (``mqnic_rx.c``): The driver writes a pointer to the page struct in ``ring->rx_info``
#. ``mqnic_prepare_rx_desc()`` (``mqnic_rx.c``): The driver writes a descriptor with the DMA pointer and length
#. ``mqnic_refill_rx_buffers()`` (``mqnic_rx.c``): The driver enqueues the descriptor by incrementing its local copy of the producer pointer
#. ``mqnic_refill_rx_buffers()`` (``mqnic_rx.c``): At the end of the loop, the driver writes the updated producer pointer to the NIC via MMIO

receive:

#. A packet arrives at the MAC
#. The MAC produces a PTP timestamp
#. :ref:`mod_mqnic_core`: data enters through receive streaming interfaces
#. :ref:`mod_mqnic_l2_ingress`: layer 2 ingress processing
#. :ref:`mod_mqnic_app_block` ``s_axis_direct_rx``: data is presented to the application section
#. :ref:`mod_mqnic_app_block` ``m_axis_direct_rx``: data is returned from the application section
#. :ref:`mod_mqnic_core`: Data passes through per-port receive async FIFO module and is transferred to core clock domain
#. :ref:`mod_mqnic_app_block` ``s_axis_sync_rx``: data is presented to the application section
#. :ref:`mod_mqnic_app_block` ``m_axis_sync_rx``: data is returned from the application section
#. :ref:`mod_mqnic_core`: Data passes enters per-interface receive FIFO module and is placed into per-port FIFOs, then aggregated into a single stream
#. :ref:`mod_mqnic_app_block` ``s_axis_if_rx``: data is presented to the application section
#. :ref:`mod_mqnic_app_block` ``m_axis_if_rx``: data is returned from the application section
#. :ref:`mod_mqnic_ingress`: ingress processing
#. :ref:`mod_rx_hash`: The receive hash module computes the packet flow hash
#. :ref:`mod_rx_checksum`: The receive checksum module computes the packet payload checksum
#. :ref:`mod_mqnic_interface_rx`: A receive request is generated
#. :ref:`mod_rx_engine`: The receive hash arrives at the receive engine
#. :ref:`mod_rx_engine`: The receive checksum arrives at the receive engine
#. :ref:`mod_rx_engine`: The receive request arrives at the receive engine
#. :ref:`mod_rx_engine` ``m_axis_rx_desc_*``: The receive engine issues a write request to the interface DMA engine
#. :ref:`mod_mqnic_interface_rx` ``rx_axis_*``: The interface DMA module writes the packet data from AXI stream to the interface local DMA RAM
#. :ref:`mod_rx_engine` ``m_axis_desc_req_*``: The receive engine issues a descriptor request
#. :ref:`mod_desc_fetch`: The descriptor request arrives at the descriptor fetch module
#. :ref:`mod_desc_fetch` ``m_axis_desc_dequeue_req_*``: The descriptor fetch module issues a dequeue request to the queue manager
#. :ref:`mod_queue_manager` ``s_axis_dequeue_req_*``: The dequeue request arrives at the queue manager module
#. :ref:`mod_queue_manager`: If the queue is not empty, the queue manager starts a dequeue operation on the queue
#. :ref:`mod_queue_manager` ``m_axis_dequeue_resp_*``: The queue manager sends a response containing the operation status and DMA address
#. :ref:`mod_desc_fetch` ``m_axis_desc_dequeue_resp_*``: The response arrives at the descriptor fetch module
#. :ref:`mod_desc_fetch` ``m_axis_req_status_*``: The descriptor module reports the descriptor fetch status
#. :ref:`mod_desc_fetch` ``m_axis_dma_read_desc_*``: The descriptor module issues a DMA read request
#. ``dma_if_pcie_us_rd`` ``s_axis_read_desc_*``: The requst arrives at the DMA read interface
#. ``dma_if_pcie_us_rd``: The DMA read interface issues a PCIe read request
#. ``dma_if_pcie_us_rd``: The read data comes back in a completion packet and is written to the descriptor fetch local DMA RAM
#. ``dma_if_pcie_us_rd`` ``m_axis_read_desc_status_*``: The DMA read interface issues a status message
#. :ref:`mod_desc_fetch` ``m_axis_desc_dequeue_commit_*``: The descriptor fetch module issues a dequeue commit message
#. :ref:`mod_queue_manager`: The queue manager commits the dequeue operation and updates the consumer pointer
#. :ref:`mod_desc_fetch` ``dma_read_desc_*``: The descriptor fetch module issues a read request to its internal DMA module
#. :ref:`mod_desc_fetch` ``m_axis_desc_*``: The internal DMA module reads the descriptor and transfers it via AXI stream
#. :ref:`mod_rx_engine`: The descriptor arrives at the receive engine
#. :ref:`mod_rx_engine`: The receive engine stores the descriptor data
#. :ref:`mod_rx_engine` ``m_axis_dma_write_desc_*``: The receive engine issues a DMA write request
#. ``dma_if_pcie_us_wr`` ``s_axis_write_desc_*``: The requst arrives at the DMA write interface
#. ``dma_if_pcie_us_wr``: The DMA write interface reads the packet data from the interface local DMA RAM
#. ``dma_if_pcie_us_wr``: The DMA write interface issues a PCIe write request
#. ``dma_if_pcie_us_wr`` ``m_axis_write_desc_status_*``: The DMA write interface issues a status message
#. :ref:`mod_rx_engine` ``m_axis_cpl_req_*``: The receive engine issues a completion write request
#. :ref:`mod_cpl_write`: The completion write module writes the completion data into its local DMA RAM
#. :ref:`mod_cpl_write` ``m_axis_cpl_enqueue_req_*``: The completion write module issues an enqueue request to the completion queue manager
#. :ref:`mod_cpl_queue_manager` ``s_axis_enqueue_req_*``: The enqueue request arrives at the completion queue manager module
#. :ref:`mod_cpl_queue_manager`: If the queue is not full, the queue manager starts an enqueue operation on the queue
#. :ref:`mod_cpl_queue_manager` ``m_axis_enqueue_resp_*``: The completion queue manager sends a response containing the operation status and DMA address
#. :ref:`mod_cpl_write` ``s_axis_cpl_enqueue_resp_*``: The response arrives at the completion write module
#. :ref:`mod_cpl_write` ``m_axis_req_status_*``: The completion write module reports the completion write status
#. :ref:`mod_desc_fetch` ``m_axis_dma_write_desc_*``: The completion write module issues a DMA write request
#. ``dma_if_pcie_us_wr`` ``s_axis_write_desc_*``: The requst arrives at the DMA write interface
#. ``dma_if_pcie_us_wr``: The DMA write interface reads the completion data from the completion write module local DMA RAM
#. ``dma_if_pcie_us_wr``: The DMA write interface issues a PCIe write request
#. ``dma_if_pcie_us_wr`` ``m_axis_write_desc_status_*``: The DMA write interface issues a status message
#. :ref:`mod_cpl_write` ``m_axis_desc_enqueue_commit_*``: The completion write module issues an enqueue commit message
#. :ref:`mod_cpl_queue_manager`: The completion queue manager commits the enqueue operation and updates the producer pointer
#. :ref:`mod_cpl_queue_manager` ``m_axis_event_*``: The completion queue manager issues an event, if armed
#. :ref:`mod_cpl_write`: The event arrives at the completion write module
#. :ref:`mod_cpl_write`: The completion write module writes the event data into its local DMA RAM
#. :ref:`mod_cpl_write` ``m_axis_cpl_enqueue_req_*``: The completion write module issues an enqueue request to the completion queue manager
#. :ref:`mod_cpl_queue_manager` ``s_axis_enqueue_req_*``: The enqueue request arrives at the completion queue manager module
#. :ref:`mod_cpl_queue_manager`: If the queue is not full, the queue manager starts an enqueue operation on the queue
#. :ref:`mod_cpl_queue_manager` ``m_axis_enqueue_resp_*``: The completion queue manager sends a response containing the operation status and DMA address
#. :ref:`mod_cpl_write` ``s_axis_cpl_enqueue_resp_*``: The response arrives at the completion write module
#. :ref:`mod_cpl_write` ``m_axis_req_status_*``: The completion write module reports the completion write status
#. :ref:`mod_desc_fetch` ``m_axis_dma_write_desc_*``: The completion write module issues a DMA write request
#. ``dma_if_pcie_us_wr`` ``s_axis_write_desc_*``: The requst arrives at the DMA write interface
#. ``dma_if_pcie_us_wr``: The DMA write interface reads the event data from the completion write module local DMA RAM
#. ``dma_if_pcie_us_wr``: The DMA write interface issues a PCIe write request
#. ``dma_if_pcie_us_wr`` ``m_axis_write_desc_status_*``: The DMA write interface issues a status message
#. :ref:`mod_cpl_write` ``m_axis_desc_enqueue_commit_*``: The completion write module issues an enqueue commit message
#. :ref:`mod_cpl_queue_manager`: The completion queue manager commits the enqueue operation and updates the producer pointer
#. :ref:`mod_cpl_queue_manager` ``m_axis_event_*``: The completion queue manager issues an interrupt, if armed
#. linux: The linux kernel calls ``mqnic_irq_handler()``
#. ``mqnic_irq_handler()`` (``mqnic_irq.c``): The driver calls the EQ handler via the notifier chain (``atomic_notifier_call_chain()``)
#. ``mqnic_eq_int()`` (``mqnic_eq.c``): The driver calls ``mqnic_process_eq()``
#. ``mqnic_process_eq()`` (``mqnic_eq.c``): The driver processes the event queue, which calls the appropriate handler (``mqnic_rx_irq()``)
#. ``mqnic_rx_irq()`` (``mqnic_rx.c``): The driver enables NAPI polling on the queue (``napi_schedule_irqoff()``)
#. ``mqnic_eq_int()`` (``mqnic_eq.c``): The driver rearms the EQ (``mqnic_arm_eq()``)
#. NAPI: The linux kernel calls ``mqnic_poll_rx_cq()``
#. ``mqnic_poll_rx_cq()`` (``mqnic_rx.c``): The driver calls ``mqnic_process_rx_cq()``
#. ``mqnic_process_rx_cq()`` (``mqnic_rx.c``): The driver reads the CQ producer pointer from the NIC
#. ``mqnic_process_rx_cq()`` (``mqnic_rx.c``): The driver reads the completion record
#. ``mqnic_process_rx_cq()`` (``mqnic_rx.c``): The driver fetches a fresh ``sk_buff`` (``napi_get_frags()``)
#. ``mqnic_process_rx_cq()`` (``mqnic_rx.c``): The driver sets the ``sk_buff`` hardware timestamp
#. ``mqnic_process_rx_cq()`` (``mqnic_rx.c``): The driver unmaps the pages (``dma_unmap_page()``)
#. ``mqnic_process_rx_cq()`` (``mqnic_rx.c``): The driver associates the pages with the ``sk_buff`` (``__skb_fill_page_desc()``)
#. ``mqnic_process_rx_cq()`` (``mqnic_rx.c``): The driver sets the ``sk_buff`` length
#. ``mqnic_process_rx_cq()`` (``mqnic_rx.c``): The driver hands off the ``sk_buff`` to ``napi_gro_frags()``
#. ``mqnic_process_rx_cq()`` (``mqnic_rx.c``): The driver dequeues the completion record by incrementing the CQ consumer pointer
#. ``mqnic_process_rx_cq()`` (``mqnic_rx.c``): The driver writes the updated CQ consumer pointer via MMIO
#. ``mqnic_process_rx_cq()`` (``mqnic_rx.c``): The driver reads the queue consumer pointer from the NIC
#. ``mqnic_process_rx_cq()`` (``mqnic_rx.c``): The driver increments the ring consumer pointer for in-order freed descriptors
#. ``mqnic_process_rx_cq()`` (``mqnic_rx.c``): The driver calls ``mqnic_refill_rx_buffers()``
#. ``mqnic_refill_rx_buffers()`` (``mqnic_rx.c``): The driver calls ``mqnic_prepare_rx_desc()`` for each empty location in the ring
#. ``mqnic_prepare_rx_desc()`` (``mqnic_rx.c``): The driver allocates memory pages (``dev_alloc_pages()``)
#. ``mqnic_prepare_rx_desc()`` (``mqnic_rx.c``): The driver maps the pages (``dev_alloc_pages()``)
#. ``mqnic_prepare_rx_desc()`` (``mqnic_rx.c``): The driver writes a pointer to the page struct in ``ring->rx_info``
#. ``mqnic_prepare_rx_desc()`` (``mqnic_rx.c``): The driver writes a descriptor with the DMA pointer and length
#. ``mqnic_refill_rx_buffers()`` (``mqnic_rx.c``): The driver enqueues the descriptor by incrementing its local copy of the producer pointer
#. ``mqnic_refill_rx_buffers()`` (``mqnic_rx.c``): At the end of the loop, the driver writes the updated producer pointer to the NIC via MMIO
#. ``mqnic_poll_rx_cq()`` (``mqnic_rx.c``): The driver disables NAPI polling, when idle (``napi_complete()``)
#. ``mqnic_poll_rx_cq()`` (``mqnic_rx.c``): The driver rearms the CQ (``mqnic_arm_cq()``)
