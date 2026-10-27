--  Minimal UEFI application: the Ada-EFI equivalent of GNU-EFI's hello.

with EFI;

package Hello is
   function Efi_Main
     (Image : EFI.Handle;
      ST    : EFI.System_Table_Access) return EFI.Status;
   pragma Export (C, Efi_Main, "efi_main");
end Hello;
