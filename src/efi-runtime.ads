--  Tiny freestanding support routines.
--
--  GCC may emit calls to memcpy/memset for record assignments and array
--  initialisation even when compiling Ada.  UEFI firmware does not export
--  these symbols, so Ada-EFI provides its own.  All Ada code is compiled
--  with -fno-builtin so that these loops are not turned back into calls
--  to themselves.

with System;

package EFI.Runtime is
   pragma Preelaborate;

   procedure Memcpy
     (Destination : System.Address;
      Source      : System.Address;
      Length      : Uintn);
   pragma Export (C, Memcpy, "memcpy");

   procedure Memset
     (Destination : System.Address;
      Value       : U8;
      Length      : Uintn);
   pragma Export (C, Memset, "memset");

   procedure Memmove
     (Destination : System.Address;
      Source      : System.Address;
      Length      : Uintn);
   pragma Export (C, Memmove, "memmove");

end EFI.Runtime;
