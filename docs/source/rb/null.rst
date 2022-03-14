.. _rb_null:

===================
Null register block
===================

The null register block has a header with type 0x00000000 and no additional fields after the header.

.. table::

    ========  ============  ======  ======  ======  ======  =============
    Address   Field         31..24  23..16  15..8   7..0    Reset value
    ========  ============  ======  ======  ======  ======  =============
    RBB+0x00  Type          Vendor ID       Type            RO 0x00000000
    --------  ------------  --------------  --------------  -------------
    RBB+0x04  Version       Major   Minor   Patch   Meta    RO -
    --------  ------------  ------  ------  ------  ------  -------------
    RBB+0x08  Next pointer  Pointer to next register block  RO -
    ========  ============  ==============================  =============

See :ref:`rb_overview` for definitions of the standard register block header fields.
