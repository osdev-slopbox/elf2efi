with System;
with System.Storage_Elements;
with EFI;             use EFI;
with EFI.Library;      use EFI.Library;
with EFI.Console;      use EFI.Console;
with EFI.Loaded_Image;
with EFI.Memory;
use type EFI.Loaded_Image_Access;
use type System.Address;

package body Hello is

   function Efi_Main
     (Image : EFI.Handle;
      ST    : EFI.System_Table_Access) return EFI.Status
   is
      Img : EFI.Loaded_Image_Access;
   begin
      Initialize_Lib (Image, ST);
      Clear_Screen;

      Print_Line ("Ada-EFI -- UEFI applications in Ada");
      Print ("Firmware: ");
      Print_Z_Wide (ST.Firmware_Vendor);
      New_Line;
      Print ("System table revision: 0x");
      Print_Hex (U64 (ST.Hdr.Revision), 8);
      New_Line;
      Print ("Boot services revision: 0x");
      Print_Hex (U64 (ST.Boot_Services.Hdr.Revision), 8);
      New_Line;
      New_Line;

      Img := EFI.Loaded_Image.Get (Image);
      if Img /= null then
         Print ("Image base: 0x");
         Print_Hex (U64 (System.Storage_Elements.To_Integer (Img.Image_Base)));
         New_Line;
         Print ("Image size: ");
         Print_Decimal (I64 (Img.Image_Size));
         Print_Line (" bytes");
      end if;

      Print ("Pool allocation: ");
      declare
         P : constant System.Address := EFI.Memory.Allocate_Pool (64);
      begin
         if P = System.Null_Address then
            Print_Line ("failed");
         else
            Print_Line ("ok");
            declare
               S : constant EFI.Status := EFI.Memory.Free_Pool (P);
               pragma Unreferenced (S);
            begin
               null;
            end;
         end if;
      end;
      New_Line;
      Print_Line ("Hello from Ada!");

      return EFI.EFI_SUCCESS;
   end Efi_Main;

end Hello;
