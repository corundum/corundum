.. _mod_queue_manager:

=================
``queue_manager``
=================

``queue_manager`` implements the queue management logic for the transmit and receive queues.  It stores host to device queue state in block RAM or ultra RAM.

Operation
=========

Communication of packet data between the Corundum NIC and the driver is mediated via descriptor and completion queues.  Descriptor queues form the host-to-NIC communications channel, carrying information about where individual packets are stored in system memory.  Completion queues form the NIC-to-host communications channel, carrying information about completed operations and associated metadata.  The descriptor and completion queues are implemented as ring buffers that reside in DMA-accessible system memory, while the NIC hardware maintains the necessary queue state information. This state information consists of a pointer to the DMA address of the ring buffer, the size of the ring buffer, the producer and consumer pointers, and a reference to the associated completion queue.  The required state for each queue fits into 128 bits.

The queue management logic for the Corundum NIC must be able to efficiently store and manage the state for thousands of queues.  This means that the queue state must be completely stored in block RAM (BRAM) or ultra RAM (URAM) on the FPGA.  Since a 128 bit RAM is required and URAM blocks are 72x4096, storing the state for 4096 queues requires only 2 URAM instances.  Utilizing URAM instances enables scaling the queue management logic to handle at least 32,768 queues per interface.

In order to support high throughput, the NIC must be able to process multiple descriptors in parallel.  Therefore, the queue management logic must track multiple in-progress operations, reporting updated queue pointers to the driver as the operations are completed.  The state required to track in-process operations is much smaller than the state required to describe the queue state itself.  Therefore the in-process operation state is stored in flip-flops and distributed RAM.

The NIC design uses two queue manager modules: ``queue_manager`` is used to manage host-to-NIC descriptor queues, while ``cpl_queue_manager`` is used to manage NIC-to-host completion queues.  The modules are similar except for a few minor differences in terms of pointer handling, fill handling, and doorbell/event generation.  Because of the similarities, this section will discuss only the operation of the ``queue_manager`` module.

The BRAM or URAM array used to store the queue state information requires several cycles of latency for each read operation, so the ``queue_manager`` is built with a pipelined architecture to facilitate multiple concurrent operations.  The pipeline supports four different operations: register read, register write, dequeue/enqueue request, and dequeue/enqueue commit.  Register-access operations over an AXI lite interface enable the driver to initialize the queue state and provide pointers to the allocated host memory as well as access the producer and consumer pointers during normal operation.

.. _fig_queue_manager_block:
.. figure:: /diagrams/svg/corundum_queue_manager_block.svg

    Block diagram of the queue manager module, showing the queue state RAM and operation table. Ind = index, Addr = DMA address, Op = index in operation table, Act = active, LS = log base 2 of queue size, Cpl = completion queue index, Tail = tail or consumer pointer, Head = head or producer pointer, Com = committed; QI = queue index; Ptr = new queue pointer

A block diagram of the queue manager module is shown in :numref:`fig_queue_manager_block`.  The BRAM or URAM array used to store the queue state information requires several cycles of latency for each read operation, so the ``queue_manager`` is built with a pipelined architecture to facilitate multiple concurrent operations.  The pipeline supports four different operations: register read, register write, dequeue/enqueue request, and dequeue/enqueue commit.  Register-access operations over an AXI lite interface enable the driver to initialize the queue state and provide pointers to the allocated host memory as well as access the producer and consumer pointers during normal operation.

.. _fig_queue_pointers:
.. figure:: /diagrams/svg/queue_pointers.svg

    Queue pointers on software ring buffers.

Each queue has three pointers associated with it, as shown in :numref:`fig_queue_pointers`---the producer pointer, the host-facing consumer pointer, and the shadow consumer pointer.  The driver has control over the producer pointer and can read the host-facing consumer pointer.  Entries between the consumer pointer and the producer pointer are under the control of the NIC and must not be modified by the driver.  The driver enqueues a descriptor by writing it into the ring buffer at the index indicated by the producer pointer, issuing a memory barrier, then incrementing the producer pointer in the queue manager.  The NIC dequeues descriptors by reading them out of the descriptor ring via DMA and incrementing the consumer pointer.  The host-facing consumer pointer must not be incremented until the descriptor read operation completes, so the queue manager maintains an internal shadow consumer pointer to keep track of read operations that have started in addition to the host-facing pointer that is updated as the read operations are completed.

The dequeue request operation on the queue manager pipeline initiates a dequeue operation on a queue.  If the target queue is disabled or empty, the operation is rejected with an *empty* or *error* status.  Otherwise, the shadow consumer pointer is incremented and the physical address of the queue element is returned, along with the queue element index and an operation tag.  Operations on any combination of queues can be initiated until the operation table is full.  The dequeue request input is stalled when the table is full.  As the read operations complete, the dequeue operations are committed to free the operation table entry and update the host-facing consumer pointer.  Operations can be committed in any order, simply setting the commit flag in the operation table, but the operation table entries will be freed and host-facing consumer pointer will be updated in-order to ensure descriptors being processed are not modified by the driver.

The operation table tracks in-process queue operations that have yet to be committed.  Entries in the table consist of an active flag, a commit flag, the queue index, and the index of the next element in the queue.  The queue state also contains a pointer to the most recent entry for that queue in the operation table.  During an enqueue operation, the operation table is checked to see if there are any outstanding operations on that queue.  If so, the consumer pointer for the most recent operation is incremented and stored in the new operation table entry.  Otherwise, the current consumer pointer is incremented.  When a dequeue commit request is received, the commit bit is set for the corresponding entry.  The entries are then committed in-order, updating the host-facing consumer pointer with the pointer from the operation table and clearing the active bit in the operation table entry.

Both the queue manager and completion queue manager modules generate notifications during enqueue operations.  In a queue manager, when the driver updates a producer pointer on an enabled queue, the module issues a doorbell event that is passed to the transmit schedulers for the associated ports.  Similarly, completion queue managers generate events on hardware enqueue operations, which are passed to the event subsystem and ultimately generate interrupts.  To reduce the number of events and interrupts, completion queues also have an *armed* status.  An armed completion queue will generate a single event, disarming itself in the process.  The driver must re-arm the queue after handling the event.
