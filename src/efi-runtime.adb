with System.Storage_Elements;
with System.Address_To_Access_Conversions;
use System.Storage_Elements;

package body EFI.Runtime is
   pragma Suppress (All_Checks);

   package Byte_Conversions is
     new System.Address_To_Access_Conversions (U8);

   function Byte_At (Base : System.Address; Offset : Uintn) return U8 is
     (Byte_Conversions.To_Pointer
        (Base + Storage_Offset (Offset)).all);

   procedure Set_Byte_At
     (Base : System.Address; Offset : Uintn; Value : U8) is
   begin
      Byte_Conversions.To_Pointer
        (Base + Storage_Offset (Offset)).all := Value;
   end Set_Byte_At;

   procedure Memcpy
     (Destination : System.Address;
      Source      : System.Address;
      Length      : Uintn)
   is
   begin
      if Length = 0 then
         return;
      end if;
      for I in Uintn range 0 .. Length - 1 loop
         Set_Byte_At (Destination, I, Byte_At (Source, I));
      end loop;
   end Memcpy;

   procedure Memset
     (Destination : System.Address;
      Value       : U8;
      Length      : Uintn)
   is
   begin
      if Length = 0 then
         return;
      end if;
      for I in Uintn range 0 .. Length - 1 loop
         Set_Byte_At (Destination, I, Value);
      end loop;
   end Memset;

   procedure Memmove
     (Destination : System.Address;
      Source      : System.Address;
      Length      : Uintn)
   is
      D : constant Uintn := Uintn (To_Integer (Destination));
      S : constant Uintn := Uintn (To_Integer (Source));
   begin
      if Length = 0 then
         return;
      end if;
      if D <= S or else D >= S + Length then
         Memcpy (Destination, Source, Length);
      else
         for I in reverse Uintn range 0 .. Length - 1 loop
            Set_Byte_At (Destination, I, Byte_At (Source, I));
         end loop;
      end if;
   end Memmove;

end EFI.Runtime;
