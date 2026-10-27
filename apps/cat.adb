with System;
with Interfaces; use type Interfaces.Unsigned_64;
with EFI; use EFI;
with EFI.Library; use EFI.Library;
with EFI.Console; use EFI.Console;
with EFI.Files;
with EFI.Loaded_Image;

package body Cat is
   use type System.Address;

   Path : constant String := "\EFI\BOOT\README.TXT";
   Buf_Size : constant := 256;

   function Efi_Main
     (Image : EFI.Handle;
      ST    : EFI.System_Table_Access) return EFI.Status
   is
      Device : Handle;
      Root   : File_Access;
      File   : File_Access;
      Buf    : aliased EFI.Files.Byte_Array (0 .. Buf_Size - 1);
      N      : Uintn;
      S      : Status;
   begin
      Initialize_Lib (Image, ST);

      Device := EFI.Loaded_Image.Device_Handle (Image);
      if Device = System.Null_Address then
         Print_Line ("No loaded image device handle");
         return EFI_NOT_FOUND;
      end if;

      S := EFI.Files.Open_Root (Device, Root);
      if Error (S) then
         Print ("OpenVolume: ");
         Print_Status (S);
         New_Line;
         return S;
      end if;

      S := EFI.Files.Open (Root, Path, File);
      if Error (S) then
         Print ("Open " & Path & ": ");
         Print_Status (S);
         New_Line;
         return S;
      end if;

      loop
         S := EFI.Files.Read (File, Buf'Address, Buf_Size, N);
         exit when Error (S) or else N = 0;
         declare
            Text : String (1 .. Natural (N));
         begin
            for I in 1 .. Text'Length loop
               Text (I) := Character'Val (Buf (I - 1));
            end loop;
            Print (Text);
         end;
      end loop;

      declare
         Ignored : constant Status := EFI.Files.Close (File);
         pragma Unreferenced (Ignored);
      begin
         null;
      end;

      New_Line;
      return EFI_SUCCESS;
   end Efi_Main;

end Cat;
