with System.Storage_Elements; use System.Storage_Elements;
use type System.Address;

package body EFI.Util is

   function WChar_At (Base : System.Address; Index : Natural) return WChar is
   begin
      return WChar_Conversions.To_Pointer
        (Base + Storage_Offset (Index * 2)).all;
   end WChar_At;

   function WString_Length (Base : System.Address) return Natural is
      I : Natural := 0;
   begin
      if Base = System.Null_Address then
         return 0;
      end if;
      while I < 16#100000# and then WChar_At (Base, I) /= 0 loop
         I := I + 1;
      end loop;
      return I;
   end WString_Length;

   procedure To_WString
     (Text   : String;
      Buffer : out WString;
      Length : out Natural)
   is
      J : Natural := Text'First;
      K : Natural := 0;
   begin
      --  Decode UTF-8 into UCS-2.  UEFI's console accepts UCS-2 on x86-64.
      --  Characters outside the BMP, and malformed sequences, become '?'.
      while J <= Text'Last loop
         declare
            B : constant U8 := Character'Pos (Text (J));
         begin
            if B < 16#80# then
               Buffer (K) := WChar (B);
               J := J + 1;
            elsif B >= 16#C2# and then B < 16#E0#
              and then J < Text'Last
            then
               Buffer (K) := WChar
                 ((U16 (B and 16#1F#) * 64)
                  + U16 (U8 (Character'Pos (Text (J + 1))) and 16#3F#));
               J := J + 2;
            elsif B >= 16#E0# and then B < 16#F0#
              and then J + 2 <= Text'Last
            then
               Buffer (K) := WChar
                 ((U16 (B and 16#0F#) * 4096)
                  + (U16 (U8 (Character'Pos (Text (J + 1))) and 16#3F#) * 64)
                  + U16 (U8 (Character'Pos (Text (J + 2))) and 16#3F#));
               J := J + 3;
            else
               Buffer (K) := WChar (Character'Pos ('?'));
               J := J + 1;
            end if;
            K := K + 1;
         end;
      end loop;
      Buffer (K) := 0;
      Length := K;
   end To_WString;

   function Offset (Base : System.Address; Bytes : Uintn)
                    return System.Address
   is
   begin
      return Base + Storage_Offset (Bytes);
   end Offset;

end EFI.Util;
