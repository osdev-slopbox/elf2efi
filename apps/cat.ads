--  Reads a text file from the volume the application was loaded from and
--  prints it.  Demonstrates EFI.Files / EFI_SIMPLE_FILE_SYSTEM_PROTOCOL.

with EFI;

package Cat is
   function Efi_Main
     (Image : EFI.Handle;
      ST    : EFI.System_Table_Access) return EFI.Status;
   pragma Export (C, Efi_Main, "efi_main");
end Cat;
