--  Global library state and protocol helpers.  Initialize_Lib plays the
--  role of GNU-EFI's InitializeLib: call it first thing in your Efi_Main.

with System;

package EFI.Library is
   pragma Preelaborate;

   procedure Initialize_Lib
     (Image_Handle : Handle;
      System_Table_Address : System_Table_Access);

   function Image_Handle return Handle;
   function System_Table return System_Table_Access;
   function Boot_Services return Boot_Services_Table_Access;
   function Runtime_Services return Runtime_Services_Table_Access;
   function Console_Out return Simple_Text_Output_Access;
   function Console_In return Simple_Text_Input_Access;

   --  Query the first interface implementing Protocol.
   function Locate_Protocol (Protocol : Guid) return System.Address;

   --  Query Protocol on a particular handle.
   function Handle_Protocol
     (H : Handle; Protocol : Guid) return System.Address;

   --  Find the first handle publishing Protocol.
   function Locate_Handle
     (Protocol : Guid;
      Search_Type : EFI.Locate_Search_Type := By_Protocol) return Handle;

   --  Number of entries in the configuration table.
   function Configuration_Count return Uintn;

   --  Address of configuration table entry Index, or Null_Address.
   function Configuration_Entry (Index : Uintn) return System.Address;

end EFI.Library;
