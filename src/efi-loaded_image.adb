with Ada.Unchecked_Conversion;
with System;
with EFI.Library;

package body EFI.Loaded_Image is
   use type System.Address;

   function To_Loaded_Image is
     new Ada.Unchecked_Conversion (System.Address, Loaded_Image_Access);

   function Get (Image : Handle) return Loaded_Image_Access is
      Addr : constant System.Address :=
        EFI.Library.Handle_Protocol (Image, Loaded_Image_Protocol_Guid);
   begin
      if Addr = System.Null_Address then
         return null;
      end if;
      return To_Loaded_Image (Addr);
   end Get;

   function Device_Handle (Image : Handle) return Handle is
      P : constant Loaded_Image_Access := Get (Image);
   begin
      if P = null then
         return System.Null_Address;
      end if;
      return P.Device_Handle;
   end Device_Handle;

   function Image_Base (Image : Handle) return System.Address is
      P : constant Loaded_Image_Access := Get (Image);
   begin
      if P = null then
         return System.Null_Address;
      end if;
      return P.Image_Base;
   end Image_Base;

   function Image_Size (Image : Handle) return Uintn is
      P : constant Loaded_Image_Access := Get (Image);
   begin
      if P = null then
         return 0;
      end if;
      return P.Image_Size;
   end Image_Size;

   function Command_Line (Image : Handle) return System.Address is
      P : constant Loaded_Image_Access := Get (Image);
   begin
      if P = null then
         return System.Null_Address;
      end if;
      return P.Load_Options;
   end Command_Line;

end EFI.Loaded_Image;
