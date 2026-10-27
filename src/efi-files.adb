with Ada.Unchecked_Conversion;
with EFI.Library;
with EFI.Util;

package body EFI.Files is
   use type System.Address;

   function To_File is
     new Ada.Unchecked_Conversion (System.Address, File_Access);
   function To_Fs is
     new Ada.Unchecked_Conversion (System.Address, Simple_File_System_Access);

   function Open_Volume
     (Fs : Simple_File_System_Access;
      Root : out File_Access) return Status
   is
      R : aliased File_Access := null;
      S : Status;
   begin
      Root := null;
      if Fs = null then
         return EFI_INVALID_PARAMETER;
      end if;
      S := Fs.Open_Volume (Fs.all'Address, R'Access);
      if not Error (S) then
         Root := R;
      end if;
      return S;
   end Open_Volume;

   function Open_Root
     (Device : Handle;
      Root   : out File_Access) return Status
   is
      Addr : constant System.Address :=
        EFI.Library.Handle_Protocol (Device, Simple_File_System_Protocol_Guid);
   begin
      Root := null;
      if Addr = System.Null_Address then
         return EFI_NOT_FOUND;
      end if;
      return Open_Volume (To_Fs (Addr), Root);
   end Open_Root;

   function Open
     (File : File_Access;
      Path : String;
      Result : out File_Access;
      Mode : File_Mode := File_Mode_Read) return Status
   is
      Buf : aliased WString (0 .. Path'Length);
      Len : Natural;
      R   : aliased File_Access := null;
      S   : Status;
   begin
      Result := null;
      if File = null then
         return EFI_INVALID_PARAMETER;
      end if;
      Util.To_WString (Path, Buf, Len);
      --  UEFI uses backslashes.  Accept either spelling.
      if Len > 0 then
         for I in 0 .. Len - 1 loop
            if Buf (I) = WChar (Character'Pos ('/')) then
               Buf (I) := WChar (Character'Pos ('\'));
            end if;
         end loop;
      end if;
      S := File.Open
        (File.all'Address, R'Access, Buf'Address, U64 (Mode), 0);
      if not Error (S) then
         Result := R;
      end if;
      return S;
   end Open;

   function Read
     (File       : File_Access;
      Buffer     : System.Address;
      Buffer_Size : Uintn;
      Read_Size  : out Uintn) return Status
   is
      N : aliased Uintn := Buffer_Size;
      S : Status;
   begin
      Read_Size := 0;
      if File = null then
         return EFI_INVALID_PARAMETER;
      end if;
      S := File.Read (File.all'Address, N'Access, Buffer);
      if not Error (S) then
         Read_Size := N;
      end if;
      return S;
   end Read;

   function Write
     (File        : File_Access;
      Buffer      : System.Address;
      Buffer_Size : Uintn) return Status
   is
      N : aliased Uintn := Buffer_Size;
   begin
      if File = null then
         return EFI_INVALID_PARAMETER;
      end if;
      return File.Write (File.all'Address, N'Access, Buffer);
   end Write;

   function Close (File : File_Access) return Status is
   begin
      if File = null then
         return EFI_INVALID_PARAMETER;
      end if;
      return File.Close (File.all'Address);
   end Close;

   function Get_Size
     (File : File_Access;
      Size : out U64) return Status
   is
      Info_Guid : aliased Guid := File_Info_Guid;
      Buf       : aliased Byte_Array (0 .. 1023);
      Buf_Size  : aliased Uintn := Buf'Length;
      S         : Status;
   begin
      Size := 0;
      if File = null then
         return EFI_INVALID_PARAMETER;
      end if;
      S := File.Get_Info
        (File.all'Address, Info_Guid'Access, Buf_Size'Access, Buf'Address);
      if Error (S) then
         return S;
      end if;
      declare
         Info : File_Info with Address => Buf'Address, Import;
      begin
         Size := Info.File_Size;
      end;
      return EFI_SUCCESS;
   end Get_Size;

end EFI.Files;
