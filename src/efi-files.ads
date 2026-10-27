--  Convenience wrappers around EFI_SIMPLE_FILE_SYSTEM_PROTOCOL and
--  EFI_FILE_PROTOCOL.  Paths are ordinary Ada strings, using either '/'
--  or '\' as the separator.

with System;

package EFI.Files is
   pragma Preelaborate;

   type Byte_Array is array (Natural range <>) of U8;

   function Open_Volume
     (Fs : Simple_File_System_Access;
      Root : out File_Access) return Status;

   function Open
     (File : File_Access;
      Path : String;
      Result : out File_Access;
      Mode : File_Mode := File_Mode_Read) return Status;

   function Open_Root
     (Device : Handle;
      Root   : out File_Access) return Status;

   function Read
     (File       : File_Access;
      Buffer     : System.Address;
      Buffer_Size : Uintn;
      Read_Size  : out Uintn) return Status;

   function Write
     (File        : File_Access;
      Buffer      : System.Address;
      Buffer_Size : Uintn) return Status;

   function Close (File : File_Access) return Status;

   function Get_Size
     (File : File_Access;
      Size : out U64) return Status;

end EFI.Files;
