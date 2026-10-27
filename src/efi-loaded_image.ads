with System;
--  Helpers for the EFI_LOADED_IMAGE_PROTOCOL.

package EFI.Loaded_Image is
   pragma Preelaborate;

   function Get (Image : Handle) return Loaded_Image_Access;

   function Device_Handle (Image : Handle) return Handle;
   function Image_Base (Image : Handle) return System.Address;
   function Image_Size (Image : Handle) return Uintn;
   function Command_Line (Image : Handle) return System.Address;

end EFI.Loaded_Image;
