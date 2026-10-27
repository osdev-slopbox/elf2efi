with System.Storage_Elements; use System.Storage_Elements;

package body EFI.Library is

   G_Image : Handle;
   G_ST    : System_Table_Access;

   procedure Initialize_Lib
     (Image_Handle : Handle;
      System_Table_Address : System_Table_Access)
   is
   begin
      G_Image := Image_Handle;
      G_ST := System_Table_Address;
   end Initialize_Lib;

   function Image_Handle return Handle is
   begin
      return G_Image;
   end Image_Handle;

   function System_Table return System_Table_Access is
   begin
      return G_ST;
   end System_Table;

   function Boot_Services return Boot_Services_Table_Access is
   begin
      if G_ST = null then
         return null;
      end if;
      return G_ST.Boot_Services;
   end Boot_Services;

   function Runtime_Services return Runtime_Services_Table_Access is
   begin
      if G_ST = null then
         return null;
      end if;
      return G_ST.Runtime_Services;
   end Runtime_Services;

   function Console_Out return Simple_Text_Output_Access is
   begin
      if G_ST = null then
         return null;
      end if;
      return G_ST.Con_Out;
   end Console_Out;

   function Console_In return Simple_Text_Input_Access is
   begin
      if G_ST = null then
         return null;
      end if;
      return G_ST.Con_In;
   end Console_In;

   function Locate_Protocol (Protocol : Guid) return System.Address is
      P     : aliased Guid := Protocol;
      Iface : aliased System.Address := System.Null_Address;
      S     : Status;
   begin
      if Boot_Services = null then
         return System.Null_Address;
      end if;
      S := Boot_Services.Locate_Protocol
        (P'Access, System.Null_Address, Iface'Access);
      if Error (S) then
         return System.Null_Address;
      end if;
      return Iface;
   end Locate_Protocol;

   function Handle_Protocol
     (H : Handle; Protocol : Guid) return System.Address
   is
      P     : aliased Guid := Protocol;
      Iface : aliased System.Address := System.Null_Address;
      S     : Status;
   begin
      if Boot_Services = null then
         return System.Null_Address;
      end if;
      S := Boot_Services.Handle_Protocol (H, P'Access, Iface'Access);
      if Error (S) then
         return System.Null_Address;
      end if;
      return Iface;
   end Handle_Protocol;

   function Locate_Handle
     (Protocol : Guid;
      Search_Type : EFI.Locate_Search_Type := By_Protocol) return Handle
   is
      P      : aliased Guid := Protocol;
      Buffer : aliased Handle := System.Null_Address;
      Size   : aliased Uintn := Handle'Size / 8;
      S      : Status;
   begin
      if Boot_Services = null then
         return System.Null_Address;
      end if;
      S := Boot_Services.Locate_Handle
        (Search_Type, P'Access, System.Null_Address, Size'Access,
         Buffer'Access);
      if Error (S) then
         return System.Null_Address;
      end if;
      return Buffer;
   end Locate_Handle;

   function Configuration_Count return Uintn is
   begin
      if G_ST = null then
         return 0;
      end if;
      return G_ST.Number_Of_Table_Entries;
   end Configuration_Count;

   function Configuration_Entry (Index : Uintn) return System.Address is
   begin
      if G_ST = null or else Index >= G_ST.Number_Of_Table_Entries then
         return System.Null_Address;
      end if;
      return G_ST.Configuration_Table + Storage_Offset (Index * 24);
   end Configuration_Entry;

end EFI.Library;
