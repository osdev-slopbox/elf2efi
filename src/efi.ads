--  Ada-EFI -- a GNU-EFI-like development environment for UEFI in Ada.
--
--  This package contains the fundamental UEFI data types, the boot and
--  runtime service tables and the most commonly used protocol definitions.
--  It is a hand-written binding for the UEFI 2.x specification, laid out
--  exactly like the C structures from GNU-EFI's efidef.h / efiprot.h.
--
--  The binding targets x86-64 UEFI.  All Ada code must be compiled with
--  -mabi=ms so that Ada subprogram calls use the Microsoft x64 calling
--  convention used by the firmware.

with Interfaces;              use Interfaces;
with System;

package EFI is
   pragma Preelaborate;

   ------------------------------------------------------------------------
   --  Basic integer types
   ------------------------------------------------------------------------

   subtype U8  is Unsigned_8;
   subtype U16 is Unsigned_16;
   subtype U32 is Unsigned_32;
   subtype U64 is Unsigned_64;
   subtype I8  is Integer_8;
   subtype I16 is Integer_16;
   subtype I32 is Integer_32;
   subtype I64 is Integer_64;

   --  UEFI's native-width integer (64-bit on x86-64).
   subtype Uintn is U64;
   subtype Intn  is I64;

   subtype Physical_Address is U64;
   subtype Virtual_Address  is U64;

   --  EFI_HANDLE and EFI_EVENT are opaque pointers.
   subtype Handle is System.Address;
   subtype Event  is System.Address;

   subtype Boolean8 is U8;
   False8 : constant Boolean8 := 0;
   True8  : constant Boolean8 := 1;

   --  A single UCS-2 code unit.  UEFI strings are arrays of these, ending
   --  in a 16-bit zero.
   subtype WChar is Unsigned_16;
   type WString is array (Natural range <>) of WChar;

   --  EFI_STATUS is an unsigned machine word.  The high bit marks errors.
   subtype Status is U64;
   EFI_ERROR_MASK : constant Status := 16#8000_0000_0000_0000#;

   function Error (S : Status) return Boolean is
     ((S and EFI_ERROR_MASK) /= 0);

   EFI_SUCCESS               : constant Status := 16#0000_0000_0000_0000#;
   EFI_LOAD_ERROR            : constant Status := 16#8000_0000_0000_0001#;
   EFI_INVALID_PARAMETER     : constant Status := 16#8000_0000_0000_0002#;
   EFI_UNSUPPORTED           : constant Status := 16#8000_0000_0000_0003#;
   EFI_BAD_BUFFER_SIZE       : constant Status := 16#8000_0000_0000_0004#;
   EFI_BUFFER_TOO_SMALL      : constant Status := 16#8000_0000_0000_0005#;
   EFI_NOT_READY             : constant Status := 16#8000_0000_0000_0006#;
   EFI_DEVICE_ERROR          : constant Status := 16#8000_0000_0000_0007#;
   EFI_WRITE_PROTECTED       : constant Status := 16#8000_0000_0000_0008#;
   EFI_OUT_OF_RESOURCES      : constant Status := 16#8000_0000_0000_0009#;
   EFI_VOLUME_CORRUPTED      : constant Status := 16#8000_0000_0000_000A#;
   EFI_VOLUME_FULL           : constant Status := 16#8000_0000_0000_000B#;
   EFI_NO_MEDIA              : constant Status := 16#8000_0000_0000_000C#;
   EFI_MEDIA_CHANGED         : constant Status := 16#8000_0000_0000_000D#;
   EFI_NOT_FOUND             : constant Status := 16#8000_0000_0000_000E#;
   EFI_ACCESS_DENIED         : constant Status := 16#8000_0000_0000_000F#;
   EFI_NO_RESPONSE           : constant Status := 16#8000_0000_0000_0010#;
   EFI_NO_MAPPING            : constant Status := 16#8000_0000_0000_0011#;
   EFI_TIMEOUT               : constant Status := 16#8000_0000_0000_0012#;
   EFI_NOT_STARTED           : constant Status := 16#8000_0000_0000_0013#;
   EFI_ALREADY_STARTED       : constant Status := 16#8000_0000_0000_0014#;
   EFI_ABORTED               : constant Status := 16#8000_0000_0000_0015#;
   EFI_ICMP_ERROR            : constant Status := 16#8000_0000_0000_0016#;
   EFI_TFTP_ERROR            : constant Status := 16#8000_0000_0000_0017#;
   EFI_PROTOCOL_ERROR        : constant Status := 16#8000_0000_0000_0018#;
   EFI_INCOMPATIBLE_VERSION  : constant Status := 16#8000_0000_0000_0019#;
   EFI_SECURITY_VIOLATION    : constant Status := 16#8000_0000_0000_001A#;
   EFI_CRC_ERROR             : constant Status := 16#8000_0000_0000_001B#;
   EFI_END_OF_MEDIA          : constant Status := 16#8000_0000_0000_001C#;
   EFI_END_OF_FILE           : constant Status := 16#8000_0000_0000_001F#;
   EFI_INVALID_LANGUAGE      : constant Status := 16#8000_0000_0000_0020#;
   EFI_COMPROMISED_DATA      : constant Status := 16#8000_0000_0000_0021#;
   EFI_IP_ADDRESS_CONFLICT   : constant Status := 16#8000_0000_0000_0022#;
   EFI_HTTP_ERROR            : constant Status := 16#8000_0000_0000_0023#;

   EFI_WARN_UNKNOWN_GLYPH    : constant Status := 1;
   EFI_WARN_DELETE_FAILURE   : constant Status := 2;
   EFI_WARN_WRITE_FAILURE    : constant Status := 3;
   EFI_WARN_BUFFER_TOO_SMALL : constant Status := 4;
   EFI_WARN_STALE_DATA       : constant Status := 5;

   ------------------------------------------------------------------------
   --  GUID
   ------------------------------------------------------------------------

   type Guid_Data4 is array (0 .. 7) of U8;

   type Guid is record
      Data1 : U32;
      Data2 : U16;
      Data3 : U16;
      Data4 : Guid_Data4;
   end record;
   pragma Convention (C, Guid);
   for Guid'Size use 128;

   type Guid_Access is access all Guid;
   pragma Convention (C, Guid_Access);

   ------------------------------------------------------------------------
   --  Table header and boot/runtime service enumerations
   ------------------------------------------------------------------------

   type Table_Header is record
      Signature  : U64;
      Revision   : U32;
      Header_Size : U32;
      CRC32      : U32;
      Reserved   : U32;
   end record;
   pragma Convention (C, Table_Header);

   EFI_SYSTEM_TABLE_SIGNATURE         : constant U64 := 16#5453_5953#; --  "SYST"
   EFI_BOOT_SERVICES_SIGNATURE        : constant U64 := 16#5652_5342#; --  "BSRV"
   EFI_RUNTIME_SERVICES_SIGNATURE     : constant U64 := 16#5652_5452#; --  "RTRV"
   EFI_SYSTEM_TABLE_REVISION          : constant U32 := 16#0002_0070#;
   EFI_1_10_SYSTEM_TABLE_REVISION     : constant U32 := 16#0001_000A#;
   EFI_2_00_SYSTEM_TABLE_REVISION     : constant U32 := 16#0002_0000#;

   --  Memory types (EFI_MEMORY_TYPE).
   subtype Memory_Type is U32;
   Efi_Reserved_Memory_Type          : constant Memory_Type := 0;
   Efi_Loader_Code                   : constant Memory_Type := 1;
   Efi_Loader_Data                   : constant Memory_Type := 2;
   Efi_Boot_Services_Code            : constant Memory_Type := 3;
   Efi_Boot_Services_Data            : constant Memory_Type := 4;
   Efi_Runtime_Services_Code         : constant Memory_Type := 5;
   Efi_Runtime_Services_Data         : constant Memory_Type := 6;
   Efi_Conventional_Memory           : constant Memory_Type := 7;
   Efi_Unusable_Memory               : constant Memory_Type := 8;
   Efi_ACPI_Reclaim_Memory           : constant Memory_Type := 9;
   Efi_ACPI_Memory_NVS               : constant Memory_Type := 10;
   Efi_Memory_Mapped_IO              : constant Memory_Type := 11;
   Efi_Memory_Mapped_IO_Port_Space   : constant Memory_Type := 12;
   Efi_Pal_Code                      : constant Memory_Type := 13;
   Efi_Persistent_Memory             : constant Memory_Type := 14;
   Efi_Unaccepted_Memory             : constant Memory_Type := 15;
   Efi_Max_Memory_Type               : constant Memory_Type := 16;

   --  Allocation types (EFI_ALLOCATE_TYPE).
   subtype Allocation_Type is U32;
   Allocate_Any_Pages      : constant Allocation_Type := 0;
   Allocate_Max_Address    : constant Allocation_Type := 1;
   Allocate_Address        : constant Allocation_Type := 2;
   Max_Allocate_Type       : constant Allocation_Type := 3;

   --  Task priority levels.
   subtype Tpl is Uintn;
   TPL_APPLICATION : constant Tpl := 4;
   TPL_CALLBACK    : constant Tpl := 8;
   TPL_NOTIFY      : constant Tpl := 16;
   TPL_HIGH_LEVEL  : constant Tpl := 31;

   --  Event types.
   subtype Event_Type is U32;
   EVT_TIMER                          : constant Event_Type := 16#8000_0000#;
   EVT_RUNTIME                        : constant Event_Type := 16#4000_0000#;
   EVT_NOTIFY_WAIT                    : constant Event_Type := 16#0000_0100#;
   EVT_NOTIFY_SIGNAL                  : constant Event_Type := 16#0000_0200#;
   EVT_SIGNAL_EXIT_BOOT_SERVICES      : constant Event_Type := 16#0000_0201#;
   EVT_SIGNAL_VIRTUAL_ADDRESS_CHANGE  : constant Event_Type := 16#0000_0202#;

   subtype Timer_Delay_Type is U32;
   Timer_Cancel      : constant Timer_Delay_Type := 0;
   Timer_Periodic    : constant Timer_Delay_Type := 1;
   Timer_Relative    : constant Timer_Delay_Type := 2;

   subtype Locate_Search_Type is U32;
   All_Handles          : constant Locate_Search_Type := 0;
   By_Register_Notify   : constant Locate_Search_Type := 1;
   By_Protocol          : constant Locate_Search_Type := 2;

   subtype Reset_Type is U32;
   Reset_Cold          : constant Reset_Type := 0;
   Reset_Warm          : constant Reset_Type := 1;
   Reset_Shutdown      : constant Reset_Type := 2;
   Reset_Platform_Specific : constant Reset_Type := 3;

   subtype Interface_Type is U32;
   EFI_NATIVE_INTERFACE : constant Interface_Type := 0;

   subtype Timer_Delay is U64;

   --  EFI_MEMORY_DESCRIPTOR
   type Memory_Descriptor is record
      Type_Id          : U32;
      Padding          : U32;
      Physical_Start   : Physical_Address;
      Virtual_Start    : Virtual_Address;
      Number_Of_Pages  : U64;
      Attribute        : U64;
   end record;
   pragma Convention (C, Memory_Descriptor);
   for Memory_Descriptor'Size use 320;

   Memory_WB  : constant U64 := 16#0000_0000_0000_0008#;
   Memory_WT  : constant U64 := 16#0000_0000_0000_0010#;
   Memory_WC  : constant U64 := 16#0000_0000_0000_0020#;
   Memory_UC  : constant U64 := 16#0000_0000_0000_0040#;

   --  EFI_TIME
   type Time is record
      Year       : U16;
      Month      : U8;
      Day        : U8;
      Hour       : U8;
      Minute     : U8;
      Second     : U8;
      Pad1       : U8;
      Nanosecond : U32;
      Time_Zone  : I16;
      Daylight   : U8;
      Pad2       : U8;
   end record;
   pragma Convention (C, Time);

   type Time_Capabilities is record
      Resolution   : U32;
      Accuracy     : U32;
      Sets_To_Zero : Boolean8;
      Pad1, Pad2, Pad3 : U8;
   end record;
   pragma Convention (C, Time_Capabilities);

   --  EFI_INPUT_KEY
   type Input_Key is record
      Scan_Code    : U16;
      Unicode_Char : WChar;
   end record;
   pragma Convention (C, Input_Key);

   ------------------------------------------------------------------------
   --  Configuration tables
   ------------------------------------------------------------------------

   type Configuration_Table is record
      Vendor_Guid  : Guid;
      Vendor_Table : System.Address;
   end record;
   pragma Convention (C, Configuration_Table);

   ------------------------------------------------------------------------
   --  Simple text protocols
   ------------------------------------------------------------------------

   type Simple_Text_Output_Mode is record
      Max_Mode_Column : U32;
      Max_Mode_Row    : U32;
      Attribute       : I32;
      Cursor_Column   : U32;
      Cursor_Row      : U32;
   end record;
   pragma Convention (C, Simple_Text_Output_Mode);

   type Simple_Text_Output_Protocol is record
      Reset         : access function
        (This : System.Address; Extended_Verification : Boolean8)
         return Status;
      Output_String : access function
        (This : System.Address; String_Address : System.Address)
         return Status;
      Test_String   : access function
        (This           : System.Address;
         String_Address : System.Address;
         Width          : access Uintn;
         Height         : access Uintn)
         return Status;
      Mode          : access Simple_Text_Output_Mode;
   end record;
   pragma Convention (C, Simple_Text_Output_Protocol);

   type Simple_Text_Output_Access is access all Simple_Text_Output_Protocol;
   pragma Convention (C, Simple_Text_Output_Access);

   type Simple_Text_Input_Protocol is record
      Reset          : access function
        (This : System.Address; Extended_Verification : Boolean8)
         return Status;
      Read_Key_Stroke : access function
        (This : System.Address; Key : access Input_Key) return Status;
      Wait_For_Key    : access function
        (This : System.Address) return Status;
   end record;
   pragma Convention (C, Simple_Text_Input_Protocol);

   type Simple_Text_Input_Access is access all Simple_Text_Input_Protocol;
   pragma Convention (C, Simple_Text_Input_Access);

   ------------------------------------------------------------------------
   --  Loaded image protocol
   ------------------------------------------------------------------------

   type Loaded_Image_Protocol;
   type Loaded_Image_Access is access all Loaded_Image_Protocol;

   type Loaded_Image_Protocol is record
      Revision          : U32;
      Parent_Handle     : Handle;
      System_Table      : System.Address;
      Device_Handle     : Handle;
      File_Path         : System.Address;
      Reserved          : System.Address;
      Load_Options_Size : U32;
      Load_Options      : System.Address;
      Image_Base        : System.Address;
      Image_Size        : Uintn;
      Image_Code_Type   : U32;
      Image_Data        : System.Address;
      Unload            : access function
        (This : System.Address) return Status;
   end record;
   pragma Convention (C, Loaded_Image_Protocol);

   ------------------------------------------------------------------------
   --  Device path and simple file system
   ------------------------------------------------------------------------

   type Device_Path_Protocol is record
      Type_Id  : U8;
      Sub_Type : U8;
      Length   : U16;
   end record;
   pragma Convention (C, Device_Path_Protocol);

   type Device_Path_Access is access all Device_Path_Protocol;

   type File_Protocol;
   type File_Access is access all File_Protocol;

   type File_Protocol is record
      Revision : U64;
      Open : access function
        (This     : System.Address;
         New_Handle : access File_Access;
         File_Name  : System.Address;
         Open_Mode  : U64;
         Attributes : U64)
         return Status;
      Close : access function
        (This : System.Address) return Status;
      Delete : access function
        (This : System.Address) return Status;
      Read : access function
        (This        : System.Address;
         Buffer_Size : access Uintn;
         Buffer      : System.Address)
         return Status;
      Write : access function
        (This        : System.Address;
         Buffer_Size : access Uintn;
         Buffer      : System.Address)
         return Status;
      Get_Position : access function
        (This : System.Address; Position : access U64) return Status;
      Set_Position : access function
        (This : System.Address; Position : U64) return Status;
      Get_Info : access function
        (This : System.Address; Information_Type : access Guid;
         Buffer_Size : access Uintn; Buffer : System.Address)
         return Status;
      Set_Info : access function
        (This : System.Address; Information_Type : access Guid;
         Buffer_Size : Uintn; Buffer : System.Address)
         return Status;
      Flush : access function
        (This : System.Address) return Status;
   end record;
   pragma Convention (C, File_Protocol);

   type Simple_File_System_Protocol is record
      Revision    : U64;
      Open_Volume : access function
        (This : System.Address; Root : access File_Access) return Status;
   end record;
   pragma Convention (C, Simple_File_System_Protocol);

   type Simple_File_System_Access is
     access all Simple_File_System_Protocol;
   pragma Convention (C, Simple_File_System_Access);

   subtype File_Mode is U64;
   File_Mode_Read      : constant File_Mode := 16#0000_0000_0000_0001#;
   File_Mode_Write     : constant File_Mode := 16#0000_0000_0000_0002#;
   File_Mode_Create    : constant File_Mode := 16#8000_0000_0000_0000#;

   subtype File_Attribute is U64;
   File_Attribute_Read_Only  : constant File_Attribute := 16#0000_0000_0000_0001#;
   File_Attribute_Hidden     : constant File_Attribute := 16#0000_0000_0000_0002#;
   File_Attribute_System     : constant File_Attribute := 16#0000_0000_0000_0004#;
   File_Attribute_Directory  : constant File_Attribute := 16#0000_0000_0000_0010#;
   File_Attribute_Archive    : constant File_Attribute := 16#0000_0000_0000_0020#;

   type File_Info is record
      Size               : U64;
      File_Size          : U64;
      Physical_Size      : U64;
      Create_Time        : Time;
      Last_Access_Time   : Time;
      Last_Modified_Time : Time;
      Attribute          : U64;
      --  File_Name : array of WChar follows, starting at offset 80.
   end record;
   pragma Convention (C, File_Info);
   for File_Info'Size use 640;

   ------------------------------------------------------------------------
   --  Boot services
   ------------------------------------------------------------------------

   type Event_Notify_Function is access procedure
     (Evt : Event; Context : System.Address);
   pragma Convention (C, Event_Notify_Function);

   type Raise_Tpl_Func is access function (New_Tpl : Tpl) return Status;
   pragma Convention (C, Raise_Tpl_Func);

   type Restore_Tpl_Func is access procedure (Old_Tpl : Tpl);
   pragma Convention (C, Restore_Tpl_Func);

   type Allocate_Pages_Func is access function
     (Allocation : Allocation_Type;
      Memory     : Memory_Type;
      Pages      : Uintn;
      Address    : access System.Address) return Status;
   pragma Convention (C, Allocate_Pages_Func);

   type Free_Pages_Func is access function
     (Memory : System.Address; Pages : Uintn) return Status;
   pragma Convention (C, Free_Pages_Func);

   type Get_Memory_Map_Func is access function
     (Memory_Map_Size     : access Uintn;
      Memory_Map          : System.Address;
      Map_Key             : access Uintn;
      Descriptor_Size     : access Uintn;
      Descriptor_Version  : access U32) return Status;
   pragma Convention (C, Get_Memory_Map_Func);

   type Allocate_Pool_Func is access function
     (Pool_Type : Memory_Type;
      Size      : Uintn;
      Buffer    : access System.Address) return Status;
   pragma Convention (C, Allocate_Pool_Func);

   type Free_Pool_Func is access function
     (Buffer : System.Address) return Status;
   pragma Convention (C, Free_Pool_Func);

   type Create_Event_Func is access function
     (Type_Of_Event  : Event_Type;
      Notify_Tpl     : Tpl;
      Notify_Function : Event_Notify_Function;
      Notify_Context : System.Address;
      Evt            : access Event) return Status;
   pragma Convention (C, Create_Event_Func);

   type Set_Timer_Func is access function
     (Evt          : Event;
      Timer_Type   : Timer_Delay_Type;
      Trigger_Time : U64) return Status;
   pragma Convention (C, Set_Timer_Func);

   type Wait_For_Event_Func is access function
     (Number_Of_Events : Uintn;
      Evt              : access Event;
      Index            : access Uintn) return Status;
   pragma Convention (C, Wait_For_Event_Func);

   type Signal_Event_Func is access function (Evt : Event) return Status;
   pragma Convention (C, Signal_Event_Func);

   type Close_Event_Func is access function (Evt : Event) return Status;
   pragma Convention (C, Close_Event_Func);

   type Check_Event_Func is access function (Evt : Event) return Status;
   pragma Convention (C, Check_Event_Func);

   type Install_Protocol_Interface_Func is access function
     (H              : access Handle;
      Protocol       : access Guid;
      Interface_Type : EFI.Interface_Type;
      Interface_Addr : System.Address) return Status;
   pragma Convention (C, Install_Protocol_Interface_Func);

   type Reinstall_Protocol_Interface_Func is access function
     (H              : Handle;
      Protocol       : access Guid;
      Old_Interface  : System.Address;
      New_Interface  : System.Address) return Status;
   pragma Convention (C, Reinstall_Protocol_Interface_Func);

   type Uninstall_Protocol_Interface_Func is access function
     (H           : Handle;
      Protocol    : access Guid;
      Interface_Addr : System.Address) return Status;
   pragma Convention (C, Uninstall_Protocol_Interface_Func);

   type Handle_Protocol_Func is access function
     (H         : Handle;
      Protocol  : access Guid;
      Interface_Addr : access System.Address) return Status;
   pragma Convention (C, Handle_Protocol_Func);

   type Register_Protocol_Notify_Func is access function
     (Protocol : access Guid;
      Evt      : Event;
      Registration : access System.Address) return Status;
   pragma Convention (C, Register_Protocol_Notify_Func);

   type Locate_Handle_Func is access function
     (Search_Type  : Locate_Search_Type;
      Protocol     : access Guid;
      Search_Key   : System.Address;
      Buffer_Size  : access Uintn;
      Buffer       : access Handle) return Status;
   pragma Convention (C, Locate_Handle_Func);

   type Locate_Device_Path_Func is access function
     (Protocol    : access Guid;
      Device_Path : access System.Address;
      Device      : access Handle) return Status;
   pragma Convention (C, Locate_Device_Path_Func);

   type Install_Configuration_Table_Func is access function
     (Vendor_Guid : access Guid;
      Table : System.Address) return Status;
   pragma Convention (C, Install_Configuration_Table_Func);

   type Load_Image_Func is access function
     (Boot_Policy        : Boolean8;
      Parent_Image_Handle : Handle;
      Device_Path        : System.Address;
      Source_Buffer      : System.Address;
      Source_Size        : Uintn;
      Image_Handle       : access Handle) return Status;
   pragma Convention (C, Load_Image_Func);

   type Start_Image_Func is access function
     (Image_Handle   : Handle;
      Exit_Data_Size : access Uintn;
      Exit_Data      : access System.Address) return Status;
   pragma Convention (C, Start_Image_Func);

   type Exit_Func is access function
     (Image_Handle   : Handle;
      Exit_Status    : Status;
      Exit_Data_Size : Uintn;
      Exit_Data      : System.Address) return Status;
   pragma Convention (C, Exit_Func);

   type Unload_Image_Func is access function
     (Image_Handle : Handle) return Status;
   pragma Convention (C, Unload_Image_Func);

   type Exit_Boot_Services_Func is access function
     (Image_Handle : Handle; Map_Key : Uintn) return Status;
   pragma Convention (C, Exit_Boot_Services_Func);

   type Get_Next_Monotonic_Count_Func is access function
     (Count : access U64) return Status;
   pragma Convention (C, Get_Next_Monotonic_Count_Func);

   type Stall_Func is access function
     (Microseconds : Uintn) return Status;
   pragma Convention (C, Stall_Func);

   type Set_Watchdog_Timer_Func is access function
     (Timeout       : Uintn;
      Watchdog_Code : U64;
      Data_Size     : Uintn;
      Watchdog_Data : System.Address) return Status;
   pragma Convention (C, Set_Watchdog_Timer_Func);

   type Connect_Controller_Func is access function
     (Controller_Handle   : Handle;
      Driver_Image_Handle : Handle;
      Remaining_Device_Path : System.Address;
      Recursive           : Boolean8) return Status;
   pragma Convention (C, Connect_Controller_Func);

   type Disconnect_Controller_Func is access function
     (Controller_Handle    : Handle;
      Driver_Image_Handle  : Handle;
      Child_Handle         : Handle) return Status;
   pragma Convention (C, Disconnect_Controller_Func);

   type Open_Protocol_Func is access function
     (H                 : Handle;
      Protocol          : access Guid;
      Interface_Addr    : access System.Address;
      Agent_Handle      : Handle;
      Controller_Handle : Handle;
      Attributes        : U32) return Status;
   pragma Convention (C, Open_Protocol_Func);

   type Close_Protocol_Func is access function
     (H                 : Handle;
      Protocol          : access Guid;
      Agent_Handle      : Handle;
      Controller_Handle : Handle) return Status;
   pragma Convention (C, Close_Protocol_Func);

   type Open_Protocol_Information_Func is access function
     (H            : Handle;
      Protocol     : access Guid;
      Entry_Buffer : access System.Address;
      Entry_Count  : access Uintn) return Status;
   pragma Convention (C, Open_Protocol_Information_Func);

   type Protocols_Per_Handle_Func is access function
     (H                    : Handle;
      Protocol_Buffer      : access System.Address;
      Protocol_Buffer_Count : access Uintn) return Status;
   pragma Convention (C, Protocols_Per_Handle_Func);

   type Locate_Handle_Buffer_Func is access function
     (Search_Type  : Locate_Search_Type;
      Protocol     : access Guid;
      Search_Key   : System.Address;
      No_Handles   : access Uintn;
      Buffer       : access System.Address) return Status;
   pragma Convention (C, Locate_Handle_Buffer_Func);

   type Locate_Protocol_Func is access function
     (Protocol     : access Guid;
      Registration : System.Address;
      Interface_Addr : access System.Address) return Status;
   pragma Convention (C, Locate_Protocol_Func);

   --  Install/UninstallMultipleProtocolInterfaces are variadic in C.  They
   --  are kept as opaque slots so that the table layout remains correct;
   --  use the single-interface calls or a thin assembly helper if needed.
   type Install_Multiple_Protocol_Interfaces_Func is access function
     (H : access Handle; Arguments : System.Address) return Status;
   pragma Convention (C, Install_Multiple_Protocol_Interfaces_Func);

   type Uninstall_Multiple_Protocol_Interfaces_Func is access function
     (H : Handle; Arguments : System.Address) return Status;
   pragma Convention (C, Uninstall_Multiple_Protocol_Interfaces_Func);

   type Calculate_CRC32_Func is access function
     (Data    : System.Address;
      Size    : Uintn;
      Crc32   : access U32) return Status;
   pragma Convention (C, Calculate_CRC32_Func);

   type Copy_Mem_Func is access procedure
     (Destination : System.Address;
      Source      : System.Address;
      Length      : Uintn);
   pragma Convention (C, Copy_Mem_Func);

   type Set_Mem_Func is access procedure
     (Buffer : System.Address;
      Size   : Uintn;
      Value  : U8);
   pragma Convention (C, Set_Mem_Func);

   type Create_Event_Ex_Func is access function
     (Type_Of_Event   : Event_Type;
      Notify_Tpl      : Tpl;
      Notify_Function : Event_Notify_Function;
      Notify_Context  : System.Address;
      Event_Group     : access Guid;
      Evt             : access Event) return Status;
   pragma Convention (C, Create_Event_Ex_Func);

   type Boot_Services_Table is record
      Hdr                          : Table_Header;
      Raise_Tpl                    : Raise_Tpl_Func;
      Restore_Tpl                  : Restore_Tpl_Func;
      Allocate_Pages               : Allocate_Pages_Func;
      Free_Pages                   : Free_Pages_Func;
      Get_Memory_Map               : Get_Memory_Map_Func;
      Allocate_Pool                : Allocate_Pool_Func;
      Free_Pool                    : Free_Pool_Func;
      Create_Event                 : Create_Event_Func;
      Set_Timer                    : Set_Timer_Func;
      Wait_For_Event               : Wait_For_Event_Func;
      Signal_Event                 : Signal_Event_Func;
      Close_Event                  : Close_Event_Func;
      Check_Event                  : Check_Event_Func;
      Install_Protocol_Interface   : Install_Protocol_Interface_Func;
      Reinstall_Protocol_Interface : Reinstall_Protocol_Interface_Func;
      Uninstall_Protocol_Interface : Uninstall_Protocol_Interface_Func;
      Handle_Protocol              : Handle_Protocol_Func;
      Reserved                     : System.Address;
      Register_Protocol_Notify     : Register_Protocol_Notify_Func;
      Locate_Handle                : Locate_Handle_Func;
      Locate_Device_Path           : Locate_Device_Path_Func;
      Install_Configuration_Table  : Install_Configuration_Table_Func;
      Load_Image                   : Load_Image_Func;
      Start_Image                  : Start_Image_Func;
      Exit_Image                   : Exit_Func;
      Unload_Image                 : Unload_Image_Func;
      Exit_Boot_Services           : Exit_Boot_Services_Func;
      Get_Next_Monotonic_Count     : Get_Next_Monotonic_Count_Func;
      Stall                        : Stall_Func;
      Set_Watchdog_Timer           : Set_Watchdog_Timer_Func;
      Connect_Controller           : Connect_Controller_Func;
      Disconnect_Controller        : Disconnect_Controller_Func;
      Open_Protocol                : Open_Protocol_Func;
      Close_Protocol               : Close_Protocol_Func;
      Open_Protocol_Information    : Open_Protocol_Information_Func;
      Protocols_Per_Handle         : Protocols_Per_Handle_Func;
      Locate_Handle_Buffer         : Locate_Handle_Buffer_Func;
      Locate_Protocol              : Locate_Protocol_Func;
      Install_Multiple_Protocol_Interfaces : Install_Multiple_Protocol_Interfaces_Func;
      Uninstall_Multiple_Protocol_Interfaces : Uninstall_Multiple_Protocol_Interfaces_Func;
      Calculate_CRC32              : Calculate_CRC32_Func;
      Copy_Mem                     : Copy_Mem_Func;
      Set_Mem                      : Set_Mem_Func;
      Create_Event_Ex              : Create_Event_Ex_Func;
   end record;
   pragma Convention (C, Boot_Services_Table);

   type Boot_Services_Table_Access is access all Boot_Services_Table;

   ------------------------------------------------------------------------
   --  Runtime services
   ------------------------------------------------------------------------

   type Get_Time_Func is access function
     (Time         : access EFI.Time;
      Capabilities : access Time_Capabilities) return Status;
   pragma Convention (C, Get_Time_Func);

   type Set_Time_Func is access function (Time : access EFI.Time) return Status;
   pragma Convention (C, Set_Time_Func);

   type Get_Wakeup_Time_Func is access function
     (Enabled      : access Boolean8;
      Pending      : access Boolean8;
      Time         : access EFI.Time) return Status;
   pragma Convention (C, Get_Wakeup_Time_Func);

   type Set_Wakeup_Time_Func is access function
     (Enabled : Boolean8; Time : access EFI.Time) return Status;
   pragma Convention (C, Set_Wakeup_Time_Func);

   type Set_Virtual_Address_Map_Func is access function
     (Memory_Map_Size    : Uintn;
      Descriptor_Size    : Uintn;
      Descriptor_Version : U32;
      Virtual_Map        : System.Address) return Status;
   pragma Convention (C, Set_Virtual_Address_Map_Func);

   type Convert_Pointer_Func is access function
     (Address : access System.Address) return Status;
   pragma Convention (C, Convert_Pointer_Func);

   type Get_Variable_Func is access function
     (Variable_Name : System.Address;
      Vendor_Guid   : access Guid;
      Attributes    : access U32;
      Data_Size     : access Uintn;
      Data          : System.Address) return Status;
   pragma Convention (C, Get_Variable_Func);

   type Get_Next_Variable_Name_Func is access function
     (Variable_Name_Size : access Uintn;
      Variable_Name      : System.Address;
      Vendor_Guid        : access Guid) return Status;
   pragma Convention (C, Get_Next_Variable_Name_Func);

   type Set_Variable_Func is access function
     (Variable_Name : System.Address;
      Vendor_Guid   : access Guid;
      Attributes    : U32;
      Data_Size     : Uintn;
      Data          : System.Address) return Status;
   pragma Convention (C, Set_Variable_Func);

   type Get_Next_High_Monotonic_Count_Func is access function
     (High_Count : access U32) return Status;
   pragma Convention (C, Get_Next_High_Monotonic_Count_Func);

   type Reset_System_Func is access procedure
     (Reset_Kind   : Reset_Type;
      Reset_Status : Status;
      Data_Size    : Uintn;
      Reset_Data   : System.Address);
   pragma Convention (C, Reset_System_Func);

   type Update_Capsule_Func is access function
     (Capsule_Header_Array : System.Address;
      Capsule_Count        : Uintn;
      Scatter_Gather_List  : Physical_Address) return Status;
   pragma Convention (C, Update_Capsule_Func);

   type Query_Capsule_Capabilities_Func is access function
     (Capsule_Header_Array    : System.Address;
      Capsule_Count           : Uintn;
      Maximum_Capsule_Size    : access U64;
      Reset_Type              : access U32) return Status;
   pragma Convention (C, Query_Capsule_Capabilities_Func);

   type Query_Variable_Info_Func is access function
     (Attributes         : U32;
      Maximum_Variable_Storage_Size : access U64;
      Remaining_Variable_Storage_Size : access U64;
      Maximum_Variable_Size : access U64) return Status;
   pragma Convention (C, Query_Variable_Info_Func);

   type Runtime_Services_Table is record
      Hdr                        : Table_Header;
      Get_Time                   : Get_Time_Func;
      Set_Time                   : Set_Time_Func;
      Get_Wakeup_Time            : Get_Wakeup_Time_Func;
      Set_Wakeup_Time            : Set_Wakeup_Time_Func;
      Set_Virtual_Address_Map    : Set_Virtual_Address_Map_Func;
      Convert_Pointer            : Convert_Pointer_Func;
      Get_Variable               : Get_Variable_Func;
      Get_Next_Variable_Name     : Get_Next_Variable_Name_Func;
      Set_Variable               : Set_Variable_Func;
      Get_Next_High_Monotonic_Count : Get_Next_High_Monotonic_Count_Func;
      Reset_System               : Reset_System_Func;
      Update_Capsule             : Update_Capsule_Func;
      Query_Capsule_Capabilities : Query_Capsule_Capabilities_Func;
      Query_Variable_Info        : Query_Variable_Info_Func;
   end record;
   pragma Convention (C, Runtime_Services_Table);

   type Runtime_Services_Table_Access is access all Runtime_Services_Table;

   ------------------------------------------------------------------------
   --  System table
   ------------------------------------------------------------------------

   type System_Table is record
      Hdr                    : Table_Header;
      Firmware_Vendor        : System.Address; --  CHAR16 *
      Firmware_Revision      : U32;
      Pad                    : U32;
      Console_In_Handle      : Handle;
      Con_In                 : Simple_Text_Input_Access;
      Console_Out_Handle     : Handle;
      Con_Out                : Simple_Text_Output_Access;
      Standard_Error_Handle  : Handle;
      Std_Err                : Simple_Text_Output_Access;
      Runtime_Services       : Runtime_Services_Table_Access;
      Boot_Services          : Boot_Services_Table_Access;
      Number_Of_Table_Entries : Uintn;
      Configuration_Table    : System.Address;
   end record;
   pragma Convention (C, System_Table);

   type System_Table_Access is access all System_Table;

   ------------------------------------------------------------------------
   --  Well-known protocol GUIDs
   ------------------------------------------------------------------------

   Loaded_Image_Protocol_Guid : constant Guid :=
     (Data1 => 16#5B1B31A1#, Data2 => 16#9562#, Data3 => 16#11D2#,
      Data4 => (16#8E#, 16#3F#, 16#00#, 16#A0#, 16#C9#, 16#69#, 16#72#, 16#3B#));

   Device_Path_Protocol_Guid : constant Guid :=
     (Data1 => 16#09576E91#, Data2 => 16#6D3F#, Data3 => 16#11D2#,
      Data4 => (16#8E#, 16#39#, 16#00#, 16#A0#, 16#C9#, 16#69#, 16#72#, 16#3B#));

   Simple_File_System_Protocol_Guid : constant Guid :=
     (Data1 => 16#964E5B22#, Data2 => 16#6459#, Data3 => 16#11D2#,
      Data4 => (16#8E#, 16#39#, 16#00#, 16#A0#, 16#C9#, 16#69#, 16#72#, 16#3B#));

   File_Info_Guid : constant Guid :=
     (Data1 => 16#09576E92#, Data2 => 16#6D3F#, Data3 => 16#11D2#,
      Data4 => (16#8E#, 16#39#, 16#00#, 16#A0#, 16#C9#, 16#69#, 16#72#, 16#3B#));

   Simple_Text_Input_Protocol_Guid : constant Guid :=
     (Data1 => 16#387477C1#, Data2 => 16#69C7#, Data3 => 16#11D2#,
      Data4 => (16#8E#, 16#39#, 16#00#, 16#A0#, 16#C9#, 16#69#, 16#72#, 16#3B#));

   Simple_Text_Output_Protocol_Guid : constant Guid :=
     (Data1 => 16#387477C2#, Data2 => 16#69C7#, Data3 => 16#11D2#,
      Data4 => (16#8E#, 16#39#, 16#00#, 16#A0#, 16#C9#, 16#69#, 16#72#, 16#3B#));

   Graphics_Output_Protocol_Guid : constant Guid :=
     (Data1 => 16#9042A9DE#, Data2 => 16#23DC#, Data3 => 16#4A38#,
      Data4 => (16#96#, 16#FB#, 16#7A#, 16#DE#, 16#D0#, 16#80#, 16#51#, 16#6A#));

   Serial_Io_Protocol_Guid : constant Guid :=
     (Data1 => 16#BB25CF6F#, Data2 => 16#F1D4#, Data3 => 16#11D2#,
      Data4 => (16#9A#, 16#0C#, 16#00#, 16#90#, 16#27#, 16#3F#, 16#C1#, 16#FD#));

   Loaded_Image_Device_Path_Guid : constant Guid :=
     (Data1 => 16#BC62157E#, Data2 => 16#3E33#, Data3 => 16#4FEC#,
      Data4 => (16#99#, 16#20#, 16#2D#, 16#3B#, 16#45#, 16#1F#, 16#D6#, 16#7F#));

   Global_Variable_Guid : constant Guid :=
     (Data1 => 16#8BE4DF61#, Data2 => 16#93CA#, Data3 => 16#11D2#,
      Data4 => (16#AA#, 16#0D#, 16#00#, 16#E0#, 16#98#, 16#03#, 16#2B#, 16#8C#));

end EFI;
