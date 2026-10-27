with EFI.Library;
with EFI.Util;
with EFI.Runtime;

package body EFI.Memory is

   function Allocate_Pool_Status
     (Size : Uintn;
      Buffer : out System.Address;
      Pool_Type : EFI.Memory_Type := Efi_Loader_Data) return Status
   is
      B : aliased System.Address := System.Null_Address;
      S : Status;
   begin
      Buffer := System.Null_Address;
      if Library.Boot_Services = null then
         return EFI_UNSUPPORTED;
      end if;
      S := Library.Boot_Services.Allocate_Pool (Pool_Type, Size, B'Access);
      if not Error (S) then
         Buffer := B;
      end if;
      return S;
   end Allocate_Pool_Status;

   function Allocate_Pool
     (Size : Uintn;
      Pool_Type : EFI.Memory_Type := Efi_Loader_Data) return System.Address
   is
      B : System.Address;
      S : Status;
      pragma Unreferenced (S);
   begin
      S := Allocate_Pool_Status (Size, B, Pool_Type);
      return B;
   end Allocate_Pool;

   function Free_Pool (Buffer : System.Address) return Status is
   begin
      if Library.Boot_Services = null then
         return EFI_UNSUPPORTED;
      end if;
      return Library.Boot_Services.Free_Pool (Buffer);
   end Free_Pool;

   function Allocate_Pages_Status
     (Pages : Uintn;
      Buffer : out System.Address;
      Kind : Memory_Type := Efi_Loader_Data) return Status
   is
      B : aliased System.Address := System.Null_Address;
      S : Status;
   begin
      Buffer := System.Null_Address;
      if Library.Boot_Services = null then
         return EFI_UNSUPPORTED;
      end if;
      S := Library.Boot_Services.Allocate_Pages
        (Allocate_Any_Pages, Kind, Pages, B'Access);
      if not Error (S) then
         Buffer := B;
      end if;
      return S;
   end Allocate_Pages_Status;

   function Allocate_Pages
     (Pages : Uintn;
      Kind : Memory_Type := Efi_Loader_Data) return System.Address
   is
      B : System.Address;
      S : Status;
      pragma Unreferenced (S);
   begin
      S := Allocate_Pages_Status (Pages, B, Kind);
      return B;
   end Allocate_Pages;

   function Free_Pages
     (Memory : System.Address; Pages : Uintn) return Status
   is
   begin
      if Library.Boot_Services = null then
         return EFI_UNSUPPORTED;
      end if;
      return Library.Boot_Services.Free_Pages (Memory, Pages);
   end Free_Pages;

   procedure Copy
     (Destination : System.Address;
      Source      : System.Address;
      Length      : Uintn)
   is
   begin
      if Library.Boot_Services = null then
         EFI.Runtime.Memcpy (Destination, Source, Length);
      else
         Library.Boot_Services.Copy_Mem (Destination, Source, Length);
      end if;
   end Copy;

   procedure Fill
     (Destination : System.Address; Length : Uintn; Value : U8)
   is
   begin
      if Library.Boot_Services = null then
         EFI.Runtime.Memset (Destination, Value, Length);
      else
         Library.Boot_Services.Set_Mem (Destination, Length, Value);
      end if;
   end Fill;

   procedure Zero (Destination : System.Address; Length : Uintn) is
   begin
      Fill (Destination, Length, 0);
   end Zero;

end EFI.Memory;
