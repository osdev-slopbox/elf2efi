--  Console output helpers, roughly the equivalent of GNU-EFI's Print(),
--  PrintLine() and the CHAR16 string utilities.

with System;

package EFI.Console is
   pragma Preelaborate;

   procedure Print (Text : String);
   procedure Print_Line (Text : String);
   procedure Print_Wide (Text : WString);
   procedure Print_Z_Wide (Text : System.Address);

   procedure New_Line;
   procedure Print_Decimal (Value : I64);
   procedure Print_Hex (Value : U64; Min_Digits : Natural := 0);
   procedure Print_Status (S : Status);
   procedure Print_Guid (G : Guid);

   procedure Clear_Screen;
   procedure Set_Attribute (Attribute : I32);

end EFI.Console;
