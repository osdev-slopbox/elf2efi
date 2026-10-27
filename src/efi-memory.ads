--  Pool/page allocation and memory utility wrappers.

with System;
with EFI.Util;

package EFI.Memory is
   pragma Preelaborate;

   function Allocate_Pool
     (Size : Uintn;
      Pool_Type : EFI.Memory_Type := Efi_Loader_Data) return System.Address;
   function Allocate_Pool_Status
     (Size : Uintn;
      Buffer : out System.Address;
      Pool_Type : EFI.Memory_Type := Efi_Loader_Data) return Status;
   function Free_Pool (Buffer : System.Address) return Status;

   function Allocate_Pages
     (Pages : Uintn;
      Kind : Memory_Type := Efi_Loader_Data) return System.Address;
   function Allocate_Pages_Status
     (Pages : Uintn;
      Buffer : out System.Address;
      Kind : Memory_Type := Efi_Loader_Data) return Status;
   function Free_Pages
     (Memory : System.Address; Pages : Uintn) return Status;

   procedure Copy
     (Destination : System.Address;
      Source      : System.Address;
      Length      : Uintn);
   procedure Zero (Destination : System.Address; Length : Uintn);
   procedure Fill
     (Destination : System.Address; Length : Uintn; Value : U8);

   function Offset (Base : System.Address; Bytes : Uintn)
                    return System.Address renames EFI.Util.Offset;

end EFI.Memory;
