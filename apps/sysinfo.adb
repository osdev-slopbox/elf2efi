with EFI; use EFI;
with System;
with Interfaces; use type Interfaces.Unsigned_64;
use type Interfaces.Unsigned_32;
with System.Storage_Elements;
use type System.Address;
with EFI.Library; use EFI.Library;
with EFI.Console; use EFI.Console;
with EFI.Memory;

package body Sysinfo is

   procedure Print_Memory_Map is
      Size         : aliased Uintn := 0;
      Capacity     : Uintn := 0;
      Map_Key      : aliased Uintn := 0;
      Desc_Size    : aliased Uintn := 0;
      Desc_Version : aliased U32 := 0;
      S            : Status;
      Buffer       : System.Address := System.Null_Address;
      Conventional : U64 := 0;
      Descriptors  : Uintn;
   begin
      for Attempt in 1 .. 4 loop
         Size := Capacity;
         S := Boot_Services.Get_Memory_Map
           (Size'Access, Buffer, Map_Key'Access,
            Desc_Size'Access, Desc_Version'Access);
         exit when not Error (S);
         if S /= EFI_BUFFER_TOO_SMALL or else Attempt = 4 then
            exit;
         end if;
         if Buffer /= System.Null_Address then
            declare
               Ignored : constant Status := EFI.Memory.Free_Pool (Buffer);
               pragma Unreferenced (Ignored);
            begin
               null;
            end;
         end if;
         Capacity := Size + 2 * Desc_Size;
         Buffer := EFI.Memory.Allocate_Pool (Capacity);
         if Buffer = System.Null_Address then
            Print_Line ("Out of memory reading the memory map");
            return;
         end if;
      end loop;

      if Error (S) then
         Print ("GetMemoryMap failed: ");
         Print_Status (S);
         New_Line;
         if Buffer /= System.Null_Address then
            declare
               Ignored : constant Status := EFI.Memory.Free_Pool (Buffer);
               pragma Unreferenced (Ignored);
            begin
               null;
            end;
         end if;
         return;
      end if;

      Descriptors := Size / Desc_Size;
      Print ("Memory map: ");
      Print_Decimal (I64 (Descriptors));
      Print_Line (" descriptors");
      Print ("  descriptor size: ");
      Print_Decimal (I64 (Desc_Size));
      Print_Line (" bytes");

      if Descriptors > 0 then
         for I in 0 .. Descriptors - 1 loop
            declare
               D : Memory_Descriptor
                 with Address =>
                   EFI.Memory.Offset (Buffer, I * Desc_Size), Import;
            begin
               if D.Type_Id = Efi_Conventional_Memory then
                  Conventional := Conventional + D.Number_Of_Pages;
               end if;
            end;
         end loop;
      end if;

      Print ("  conventional memory: ");
      Print_Decimal (I64 (Conventional / 256));
      Print_Line (" MiB");

      declare
         Ignored : constant Status := EFI.Memory.Free_Pool (Buffer);
         pragma Unreferenced (Ignored);
      begin
         null;
      end;
   end Print_Memory_Map;

   procedure Print_Configuration_Table is
      Count : constant Uintn := Configuration_Count;
   begin
      Print ("Configuration table entries: ");
      Print_Decimal (I64 (Count));
      New_Line;
      if Count > 0 then
         for I in 0 .. Count - 1 loop
            declare
               E : Configuration_Table
                 with Address => Configuration_Entry (I), Import;
            begin
               Print ("  ");
               Print_Guid (E.Vendor_Guid);
               New_Line;
            end;
         end loop;
      end if;
   end Print_Configuration_Table;

   function Efi_Main
     (Image : EFI.Handle;
      ST    : EFI.System_Table_Access) return EFI.Status
   is
   begin
      Initialize_Lib (Image, ST);
      Clear_Screen;
      Print_Line ("Ada-EFI system information");
      Print ("Firmware vendor: ");
      Print_Z_Wide (ST.Firmware_Vendor);
      New_Line;
      Print ("Firmware revision: 0x");
      Print_Hex (U64 (ST.Firmware_Revision), 8);
      New_Line;
      Print ("System table revision: 0x");
      Print_Hex (U64 (ST.Hdr.Revision), 8);
      New_Line;
      New_Line;
      Print_Configuration_Table;
      New_Line;
      Print_Memory_Map;
      New_Line;
      Print_Line ("Done.");
      return EFI_SUCCESS;
   end Efi_Main;

end Sysinfo;
