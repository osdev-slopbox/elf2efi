--  Prints firmware, configuration table and memory map information.

with EFI;

package Sysinfo is
   function Efi_Main
     (Image : EFI.Handle;
      ST    : EFI.System_Table_Access) return EFI.Status;
   pragma Export (C, Efi_Main, "efi_main");
end Sysinfo;
