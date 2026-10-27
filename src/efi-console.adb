with System;
with EFI.Library;
with EFI.Util;
use type System.Address;

package body EFI.Console is

   procedure Output_Address (S : System.Address) is
      Outp   : constant Simple_Text_Output_Access := Library.Console_Out;
      Result : Status;
      pragma Unreferenced (Result);
   begin
      if Outp = null or else S = System.Null_Address then
         return;
      end if;
      Result := Outp.Output_String (Outp.all'Address, S);
   end Output_Address;

   procedure Print (Text : String) is
      Buf : aliased WString (0 .. Text'Length);
      Len : Natural;
   begin
      Util.To_WString (Text, Buf, Len);
      Output_Address (Buf'Address);
   end Print;

   procedure Print_Wide (Text : WString) is
      Buf : aliased WString (0 .. Text'Length);
   begin
      if Text'Length > 0 then
         Buf (0 .. Text'Length - 1) := Text;
      end if;
      Buf (Text'Length) := 0;
      Output_Address (Buf'Address);
   end Print_Wide;

   procedure Print_Z_Wide (Text : System.Address) is
      Len : Natural;
   begin
      if Text = System.Null_Address then
         return;
      end if;
      Len := Util.WString_Length (Text);
      declare
         Buf : aliased WString (0 .. Len);
      begin
         for I in 0 .. Len - 1 loop
            Buf (I) := Util.WChar_At (Text, I);
         end loop;
         Buf (Len) := 0;
         Output_Address (Buf'Address);
      end;
   end Print_Z_Wide;

   procedure New_Line is
      Buf : aliased WString (0 .. 2) := (16#0D#, 16#0A#, 0);
   begin
      Output_Address (Buf'Address);
   end New_Line;

   procedure Print_Line (Text : String) is
   begin
      Print (Text);
      New_Line;
   end Print_Line;

   procedure Print_Decimal (Value : I64) is
      U      : U64 := U64 (Value);
      Neg    : constant Boolean := Value < 0;
      Buffer : String (1 .. 21);
      Pos    : Natural := Buffer'Last + 1;
      Digit  : U64;
   begin
      if Neg then
         --  Avoid overflow for I64'First by negating one step earlier.
         U := U64 (-(Value + 1)) + 1;
      end if;
      if U = 0 then
         Pos := Pos - 1;
         Buffer (Pos) := '0';
      end if;
      while U /= 0 loop
         Digit := U mod 10;
         U := U / 10;
         Pos := Pos - 1;
         Buffer (Pos) := Character'Val (Digit + Character'Pos ('0'));
      end loop;
      if Neg then
         Pos := Pos - 1;
         Buffer (Pos) := '-';
      end if;
      Print (Buffer (Pos .. Buffer'Last));
   end Print_Decimal;

   procedure Print_Hex (Value : U64; Min_Digits : Natural := 0) is
      Hex    : constant String := "0123456789ABCDEF";
      Buffer : String (1 .. 16);
      Pos    : Natural := Buffer'Last + 1;
      U      : U64 := Value;
      Count  : Natural := 0;
   begin
      if U = 0 then
         Pos := Pos - 1;
         Buffer (Pos) := '0';
         Count := 1;
      end if;
      while U /= 0 loop
         Pos := Pos - 1;
         Buffer (Pos) := Hex (Natural (U mod 16) + 1);
         U := U / 16;
         Count := Count + 1;
      end loop;
      while Count < Min_Digits loop
         Pos := Pos - 1;
         Buffer (Pos) := '0';
         Count := Count + 1;
      end loop;
      Print (Buffer (Pos .. Buffer'Last));
   end Print_Hex;

   procedure Print_Status (S : Status) is
   begin
      if S = EFI_SUCCESS then
         Print ("EFI_SUCCESS");
      elsif S = EFI_LOAD_ERROR then
         Print ("EFI_LOAD_ERROR");
      elsif S = EFI_INVALID_PARAMETER then
         Print ("EFI_INVALID_PARAMETER");
      elsif S = EFI_UNSUPPORTED then
         Print ("EFI_UNSUPPORTED");
      elsif S = EFI_BAD_BUFFER_SIZE then
         Print ("EFI_BAD_BUFFER_SIZE");
      elsif S = EFI_BUFFER_TOO_SMALL then
         Print ("EFI_BUFFER_TOO_SMALL");
      elsif S = EFI_NOT_READY then
         Print ("EFI_NOT_READY");
      elsif S = EFI_DEVICE_ERROR then
         Print ("EFI_DEVICE_ERROR");
      elsif S = EFI_OUT_OF_RESOURCES then
         Print ("EFI_OUT_OF_RESOURCES");
      elsif S = EFI_NOT_FOUND then
         Print ("EFI_NOT_FOUND");
      elsif S = EFI_ACCESS_DENIED then
         Print ("EFI_ACCESS_DENIED");
      elsif S = EFI_ABORTED then
         Print ("EFI_ABORTED");
      elsif S = EFI_SECURITY_VIOLATION then
         Print ("EFI_SECURITY_VIOLATION");
      else
         Print ("EFI_STATUS 0x");
         Print_Hex (S);
      end if;
   end Print_Status;

   procedure Print_Guid (G : Guid) is
   begin
      Print_Hex (U64 (G.Data1), 8);
      Print ("-");
      Print_Hex (U64 (G.Data2), 4);
      Print ("-");
      Print_Hex (U64 (G.Data3), 4);
      Print ("-");
      for I in 0 .. 1 loop
         Print_Hex (U64 (G.Data4 (I)), 2);
      end loop;
      Print ("-");
      for I in 2 .. 7 loop
         Print_Hex (U64 (G.Data4 (I)), 2);
      end loop;
   end Print_Guid;

   procedure Clear_Screen is
      Outp   : constant Simple_Text_Output_Access := Library.Console_Out;
      Result : Status;
      pragma Unreferenced (Result);
   begin
      if Outp = null then
         return;
      end if;
      Result := Outp.Reset (Outp.all'Address, False8);
   end Clear_Screen;

   procedure Set_Attribute (Attribute : I32) is
      Outp : constant Simple_Text_Output_Access := Library.Console_Out;
   begin
      if Outp /= null and then Outp.Mode /= null then
         Outp.Mode.Attribute := Attribute;
      end if;
   end Set_Attribute;

end EFI.Console;
