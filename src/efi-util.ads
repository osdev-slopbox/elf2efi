--  Small helpers shared by the Ada-EFI library.

with System;
with System.Storage_Elements;
with System.Address_To_Access_Conversions;

package EFI.Util is
   pragma Preelaborate;

   package WChar_Conversions is
     new System.Address_To_Access_Conversions (WChar);

   --  Read a 16-bit character at Base + 2 * Index.  This is used for
   --  firmware-provided NUL terminated strings.
   function WChar_At (Base : System.Address; Index : Natural) return WChar;

   --  Length of a NUL terminated 16-bit string.  The scan is capped at
   --  16#100000# characters to avoid looping forever on bad pointers.
   function WString_Length (Base : System.Address) return Natural;

   --  Convert an ASCII/UTF-8 Ada string into a stack buffer.  The caller
   --  provides the buffer; the result is NUL terminated.  Returns the
   --  number of 16-bit code units written (not counting the terminator).
   procedure To_WString
     (Text   : String;
      Buffer : out WString;
      Length : out Natural);

   --  Address arithmetic for the common "base + byte offset" operation.
   function Offset (Base : System.Address; Bytes : Uintn)
                    return System.Address;

end EFI.Util;
