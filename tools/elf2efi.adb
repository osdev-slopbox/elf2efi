--  elf2efi -- convert a linked ELF64 x86-64 image into a PE32+ UEFI
--  application.
--
--  Ada-EFI links applications as position independent ELF executables whose
--  virtual addresses start at 0.  GNU ld records every absolute pointer in
--  .rela.dyn as an R_X86_64_RELATIVE relocation.  This tool lays the alloc
--  sections out as a PE image and turns those relocations into PE base
--  relocations, so the firmware can load the image at any address.

with Ada.Command_Line;
with Ada.Streams; use Ada.Streams;
with Ada.Streams.Stream_IO; use Ada.Streams.Stream_IO;
with Ada.Text_IO;
with Ada.Exceptions;
with Ada.Containers.Vectors;

with Interfaces; use Interfaces;

procedure Elf2Efi is

   type Byte is mod 256;
   for Byte'Size use 8;

   subtype U16 is Interfaces.Unsigned_16;
   subtype U32 is Interfaces.Unsigned_32;
   subtype U64 is Interfaces.Unsigned_64;

   type Byte_Array is array (Positive range <>) of Byte;

   ------------------------------------------------------------------------
   --  Error reporting
   ------------------------------------------------------------------------

   Conversion_Error : exception;

   procedure Fail (Message : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                            "elf2efi: " & Message);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      raise Conversion_Error;
   end Fail;

   ------------------------------------------------------------------------
   --  Little-endian helpers
   ------------------------------------------------------------------------

   function Get_U16 (D : Byte_Array; Off : Natural) return U16 is
     (U16 (D (D'First + Off))
      or Shift_Left (U16 (D (D'First + Off + 1)), 8));

   function Get_U32 (D : Byte_Array; Off : Natural) return U32 is
     (U32 (D (D'First + Off))
      or Shift_Left (U32 (D (D'First + Off + 1)), 8)
      or Shift_Left (U32 (D (D'First + Off + 2)), 16)
      or Shift_Left (U32 (D (D'First + Off + 3)), 24));

   function Get_U64 (D : Byte_Array; Off : Natural) return U64 is
     (U64 (Get_U32 (D, Off))
      or Shift_Left (U64 (Get_U32 (D, Off + 4)), 32));

   procedure Put_U8
     (D : in out Byte_Array; Off : Natural; V : U64)
   is
   begin
      D (D'First + Off) := Byte (V and 16#FF#);
   end Put_U8;

   procedure Put_U16
     (D : in out Byte_Array; Off : Natural; V : U64)
   is
   begin
      Put_U8 (D, Off, V and 16#FFFF#);
      Put_U8 (D, Off + 1, Shift_Right (V, 8) and 16#FFFF#);
   end Put_U16;

   procedure Put_U32
     (D : in out Byte_Array; Off : Natural; V : U64)
   is
   begin
      Put_U16 (D, Off, V and 16#FFFF_FFFF#);
      Put_U16 (D, Off + 2, Shift_Right (V, 16) and 16#FFFF_FFFF#);
   end Put_U32;

   procedure Put_U64
     (D : in out Byte_Array; Off : Natural; V : U64)
   is
   begin
      Put_U32 (D, Off, V and 16#FFFF_FFFF#);
      Put_U32 (D, Off + 4, Shift_Right (V, 32));
   end Put_U64;

   function Align_Up (Value : U64; Alignment : U64) return U64 is
   begin
      return (Value + Alignment - 1) / Alignment * Alignment;
   end Align_Up;

   ------------------------------------------------------------------------
   --  ELF data
   ------------------------------------------------------------------------

   type Section is record
      Name_Index : U32 := 0;
      Typ        : U32 := 0;
      Flags      : U64 := 0;
      Addr       : U64 := 0;
      Offset     : U64 := 0;
      Size       : U64 := 0;
      Link       : U32 := 0;
      Info       : U32 := 0;
      Align      : U64 := 0;
      Entsize    : U64 := 0;
      Name       : String (1 .. 64) := (others => ' ');
      Name_Len   : Natural := 0;
      Keep       : Boolean := False;
      Pe_Index   : Natural := 0;
   end record;

   package Section_Vectors is new Ada.Containers.Vectors
     (Index_Type => Natural, Element_Type => Section);

   package Reloc_Vectors is new Ada.Containers.Vectors
     (Index_Type => Natural, Element_Type => U64);

   package Reloc_Sorting is new Reloc_Vectors.Generic_Sorting;

   SHT_PROGBITS : constant U32 := 1;
   SHT_SYMTAB   : constant U32 := 2;
   SHT_STRTAB   : constant U32 := 3;
   SHT_RELA     : constant U32 := 4;
   SHT_NOBITS   : constant U32 := 8;

   SHF_WRITE     : constant U64 := 1;
   SHF_ALLOC     : constant U64 := 2;
   SHF_EXECINSTR : constant U64 := 4;

   R_X86_64_64        : constant U32 := 1;
   R_X86_64_GLOB_DAT  : constant U32 := 6;
   R_X86_64_JUMP_SLOT : constant U32 := 7;
   R_X86_64_RELATIVE  : constant U32 := 8;

   function Is_Metadata (Name : String; Len : Natural) return Boolean is
      N : constant String := Name (1 .. Len);
   begin
      return N = ".dynamic" or else N = ".dynsym" or else N = ".dynstr"
        or else N = ".hash" or else N = ".gnu.hash"
        or else N = ".interp" or else N = ".plt" or else N = ".plt.got"
        or else N = ".rela.dyn" or else N = ".rela.plt"
        or else N = ".rel.dyn" or else N = ".rel.plt"
        or else N = ".eh_frame" or else N = ".eh_frame_hdr"
        or else N = ".note.gnu.property" or else N = ".note.gnu.build-id"
        or else N = ".note.GNU-stack" or else N = ".comment"
        or else N = ".symtab" or else N = ".strtab" or else N = ".shstrtab";
   end Is_Metadata;

   function Is_Exec (S : Section) return Boolean is
     ((S.Flags and SHF_EXECINSTR) /= 0);

   ------------------------------------------------------------------------
   --  Converter
   ------------------------------------------------------------------------

   procedure Convert (Input_Name : String; Output_Name : String;
                      Verbose : Boolean)
   is
      In_F     : File_Type;
      Size     : Natural;
      Sections : Section_Vectors.Vector;
      Entry_Point : U64;
      Shoff    : U64;
      Shentsize : U16;
      Shnum    : U16;
      Shstrndx : U16;
      Shstr_Off : U64;
      Shstr_Size : U64;
      Relocs   : Reloc_Vectors.Vector;
   begin
      --  Read the whole input file.
      Stream_IO.Open (In_F, Stream_IO.In_File, Input_Name);
      Size := Natural (Stream_IO.Size (In_F));
      if Size < 64 then
         Stream_IO.Close (In_F);
         Fail ("input is too small to be an ELF file");
      end if;
      declare
         File_Data : Byte_Array (1 .. Size);
         Raw : Stream_Element_Array (0 .. Stream_Element_Offset (Size - 1));
         Last : Stream_Element_Offset;
      begin
         Stream_IO.Read (In_F, Raw, Last);
         Stream_IO.Close (In_F);
         for I in 0 .. Size - 1 loop
            File_Data (I + 1) := Byte (Raw (Stream_Element_Offset (I)));
         end loop;

         --  Validate the ELF header.
         if File_Data (1) /= 16#7F#
           or else File_Data (2) /= Byte (Character'Pos ('E'))
           or else File_Data (3) /= Byte (Character'Pos ('L'))
           or else File_Data (4) /= Byte (Character'Pos ('F'))
         then
            Fail ("not an ELF file");
         end if;
         if File_Data (5) /= 2 then
            Fail ("only ELF64 is supported");
         end if;
         if File_Data (6) /= 1 then
            Fail ("only little-endian ELF is supported");
         end if;
         if Get_U16 (File_Data, 18) /= 62 then
            Fail ("only x86-64 ELF input is supported");
         end if;

         Entry_Point := Get_U64 (File_Data, 24);
         if Entry_Point = 0 then
            Fail ("ELF entry point is zero");
         end if;
         Shoff := Get_U64 (File_Data, 40);
         Shentsize := Get_U16 (File_Data, 58);
         Shnum := Get_U16 (File_Data, 60);
         Shstrndx := Get_U16 (File_Data, 62);

         if Shnum = 0 then
            Fail ("ELF file has no section headers (strip them?)");
         end if;
         if Shentsize /= 64 then
            Fail ("unexpected ELF section header size");
         end if;
         if Shoff + U64 (Shnum) * 64 > U64 (Size) then
            Fail ("ELF section headers lie outside the file");
         end if;

         --  Load section headers.
         for I in 1 .. Natural (Shnum) loop
            declare
               Base : constant Natural :=
                 Natural (Shoff) + (I - 1) * 64;
               S : Section;
            begin
               S.Name_Index := Get_U32 (File_Data, Base);
               S.Typ := Get_U32 (File_Data, Base + 4);
               S.Flags := Get_U64 (File_Data, Base + 8);
               S.Addr := Get_U64 (File_Data, Base + 16);
               S.Offset := Get_U64 (File_Data, Base + 24);
               S.Size := Get_U64 (File_Data, Base + 32);
               S.Link := Get_U32 (File_Data, Base + 40);
               S.Info := Get_U32 (File_Data, Base + 44);
               S.Align := Get_U64 (File_Data, Base + 48);
               S.Entsize := Get_U64 (File_Data, Base + 56);
               Sections.Append (S);
            end;
         end loop;

         if Shstrndx = 0 or else Natural (Shstrndx) >= Natural (Shnum) then
            Fail ("invalid section name string table index");
         end if;
         Shstr_Off := Sections.Element (Natural (Shstrndx)).Offset;
         Shstr_Size := Sections.Element (Natural (Shstrndx)).Size;
         if Shstr_Off + Shstr_Size > U64 (Size) then
            Fail ("section name table lies outside the file");
         end if;

         --  Resolve names and choose the sections that go into the image.
         for I in 0 .. Sections.Last_Index loop
            declare
               S : Section := Sections.Element (I);
               Pos : U64 := Shstr_Off + U64 (S.Name_Index);
               Len : Natural := 0;
            begin
               while Pos + U64 (Len) < Shstr_Off + Shstr_Size
                 and then File_Data (Natural (Pos) + Len + 1) /= 0
                 and then Len < 63
               loop
                  Len := Len + 1;
               end loop;
               S.Name_Len := Len;
               for J in 1 .. Len loop
                  S.Name (J) := Character'Val
                    (File_Data (Natural (Pos) + J));
               end loop;
               S.Keep := (S.Flags and SHF_ALLOC) /= 0
                 and then (S.Typ = SHT_PROGBITS or else S.Typ = SHT_NOBITS)
                 and then S.Size > 0
                 and then not Is_Metadata (S.Name, S.Name_Len);
               Sections.Replace_Element (I, S);
            end;
         end loop;

         --  Collect base relocations.  Only RELATIVE (and absolute) forms
         --  can survive in a linked image based at zero.
         Relocs := Reloc_Vectors.Empty_Vector;
         for I in 0 .. Sections.Last_Index loop
            declare
               S : constant Section := Sections.Element (I);
            begin
               if S.Typ = SHT_RELA and then S.Entsize = 24
                 and then S.Size >= 24
               then
                  if S.Offset + S.Size > U64 (Size) then
                     Fail ("relocation section lies outside the file");
                  end if;
                  for J in 0 .. Natural (S.Size / 24) - 1 loop
                     declare
                        Base : constant Natural :=
                          Natural (S.Offset) + J * 24;
                        Off  : constant U64 := Get_U64 (File_Data, Base);
                        Info : constant U64 := Get_U64 (File_Data, Base + 8);
                        Typ  : constant U32 := U32 (Info and 16#FFFF_FFFF#);
                     begin
                        if Typ = R_X86_64_RELATIVE
                          or else Typ = R_X86_64_64
                          or else Typ = R_X86_64_GLOB_DAT
                          or else Typ = R_X86_64_JUMP_SLOT
                        then
                           --  The linker already stored the zero-based
                           --  pointer; a PE DIR64 relocation is enough.
                           Relocs.Append (Off);
                        elsif Typ /= 0 then
                           Fail ("unsupported relocation type"
                                 & U32'Image (Typ));
                        end if;
                     end;
                  end loop;
               end if;
            end;
         end loop;
         Reloc_Sorting.Sort (Relocs);

         --  Validate layout and assign PE section numbers.
         declare
            Next_Addr : U64 := 0;
            Pe_Count  : Natural := 0;
         begin
            for I in 0 .. Sections.Last_Index loop
               declare
                  S : Section := Sections.Element (I);
               begin
                  if S.Keep then
                     if S.Addr mod 16#1000# /= 0 then
                        Fail ("section " & S.Name (1 .. S.Name_Len)
                              & " is not page aligned; use the supplied"
                              & " linker script");
                     end if;
                     if S.Addr < Next_Addr then
                        Fail ("overlapping or unsorted sections");
                     end if;
                     Next_Addr := S.Addr + S.Size;
                     Pe_Count := Pe_Count + 1;
                     S.Pe_Index := Pe_Count;
                     Sections.Replace_Element (I, S);
                  end if;
               end;
            end loop;
            if Pe_Count = 0 then
               Fail ("no loadable sections found");
            end if;
         end;

         --  Sort the kept sections by address.  The linker script emits
         --  them in order already, but do not rely on it.
         declare
            Sorted : Section_Vectors.Vector := Section_Vectors.Empty_Vector;
         begin
            for I in 0 .. Sections.Last_Index loop
               if Sections.Element (I).Keep then
                  Sorted.Append (Sections.Element (I));
               end if;
            end loop;
            for I in 0 .. Sorted.Last_Index loop
               for J in I + 1 .. Sorted.Last_Index loop
                  if Sorted.Element (J).Addr < Sorted.Element (I).Addr then
                     declare
                        A : constant Section := Sorted.Element (I);
                        B : constant Section := Sorted.Element (J);
                     begin
                        Sorted.Replace_Element (I, B);
                        Sorted.Replace_Element (J, A);
                     end;
                  end if;
               end loop;
            end loop;
            Sections := Sorted;
         end;

         -----------------------------------------------------------------
         --  Relocation block layout
         -----------------------------------------------------------------

         declare
         function Reloc_Size return U64 is
            Total : U64 := 0;
            I     : Natural := 0;
         begin
            while I <= Relocs.Last_Index loop
               declare
                  Page  : constant U64 := Relocs.Element (I) and not 16#FFF#;
                  Count : U64 := 0;
               begin
                  while I <= Relocs.Last_Index
                    and then (Relocs.Element (I) and not 16#FFF#) = Page
                  loop
                     Count := Count + 1;
                     I := I + 1;
                  end loop;
                  Total := Total + Align_Up (8 + 2 * Count, 4);
               end;
            end loop;
            return Total;
         end Reloc_Size;

         Reloc_Total : constant U64 :=
           (if Relocs.Is_Empty then U64'(0) else Reloc_Size);

         -----------------------------------------------------------------
         --  Compute PE layout
         -----------------------------------------------------------------

         Num_Sections : constant Natural :=
           Natural (Sections.Length) + (if Reloc_Total > 0 then 1 else 0);
         Header_Size : constant U64 :=
           Align_Up (16#84# + 20 + 16#F0# + U64 (Num_Sections) * 40,
                     16#200#);
         Section_Align : constant U64 := 16#1000#;
         File_Align    : constant U64 := 16#200#;
      begin
         --  Assign RVAs and file offsets.
         declare
            type Pe_Section is record
               Name            : String (1 .. 8) := (others => ' ');
               Name_Len        : Natural := 0;
               Virtual_Size    : U64 := 0;
               Virtual_Address : U64 := 0;
               Raw_Size        : U64 := 0;
               Raw_Offset      : U64 := 0;
               Characteristics : U32 := 0;
               Elf_Index       : Natural := 0;
               Is_Bss          : Boolean := False;
            end record;
            type Pe_Array is array (Positive range <>) of Pe_Section;
            Pe : Pe_Array (1 .. Num_Sections);
            Raw_Cursor : U64 := Header_Size;
            Last_End   : U64 := 0;
            Code_Size  : U64 := 0;
            Init_Size  : U64 := 0;
            Uninit_Size : U64 := 0;
            Reloc_Index : Natural := 0;
            Base_Code  : U64 := 16#1000#;
         begin
            for I in 0 .. Sections.Last_Index loop
               declare
                  S : constant Section := Sections.Element (I);
                  P : Pe_Section;
               begin
                  P.Elf_Index := I;
                  P.Virtual_Size := S.Size;
                  P.Virtual_Address := S.Addr;
                  P.Name_Len := Natural'Min (S.Name_Len, 8);
                  if P.Name_Len > 0 then
                     P.Name (1 .. P.Name_Len) :=
                       S.Name (1 .. P.Name_Len);
                  end if;
                  if S.Typ = SHT_NOBITS then
                     P.Raw_Size := 0;
                     P.Raw_Offset := 0;
                     P.Characteristics := 16#C000_0080#;
                     P.Is_Bss := True;
                     Uninit_Size := Uninit_Size + S.Size;
                  else
                     P.Raw_Size := Align_Up (S.Size, File_Align);
                     P.Raw_Offset := Raw_Cursor;
                     Raw_Cursor := Raw_Cursor + P.Raw_Size;
                     if Is_Exec (S) then
                        P.Characteristics := 16#6000_0020#;
                        Code_Size := Code_Size + P.Raw_Size;
                        if S.Addr < Base_Code then
                           Base_Code := S.Addr;
                        end if;
                     elsif (S.Flags and SHF_WRITE) /= 0 then
                        P.Characteristics := 16#C000_0040#;
                        Init_Size := Init_Size + P.Raw_Size;
                     else
                        P.Characteristics := 16#4000_0040#;
                        Init_Size := Init_Size + P.Raw_Size;
                     end if;
                  end if;
                  Last_End := S.Addr + S.Size;
                  Pe (I + 1) := P;
               end;
            end loop;

            if Reloc_Total > 0 then
               Reloc_Index := Num_Sections;
               Pe (Num_Sections).Name (1 .. 6) := ".reloc";
               Pe (Num_Sections).Name_Len := 6;
               Pe (Num_Sections).Virtual_Address :=
                 Align_Up (Last_End, Section_Align);
               Pe (Num_Sections).Virtual_Size := Reloc_Total;
               Pe (Num_Sections).Raw_Size :=
                 Align_Up (Reloc_Total, File_Align);
               Pe (Num_Sections).Raw_Offset := Raw_Cursor;
               Pe (Num_Sections).Characteristics := 16#4200_0040#;
               Raw_Cursor := Raw_Cursor + Pe (Num_Sections).Raw_Size;
               Last_End := Pe (Num_Sections).Virtual_Address + Reloc_Total;
            end if;

            declare
               Size_Of_Image : constant U64 :=
                 Align_Up (Last_End, Section_Align);
               File_Size : constant Natural := Natural (Raw_Cursor);
               Img : Byte_Array (1 .. File_Size);
            begin
               --  Zero the whole image first.
               for I in Img'Range loop
                  Img (I) := 0;
               end loop;

               --  DOS header and PE headers.
               Img (1) := Character'Pos ('M');
               Img (2) := Character'Pos ('Z');
               Put_U32 (Img, 16#3C#, 16#80#);
               Img (16#80# + 1) := Character'Pos ('P');
               Img (16#80# + 2) := Character'Pos ('E');

               Put_U16 (Img, 16#84#, 16#8664#);
               Put_U16 (Img, 16#86#, U64 (Num_Sections));
               Put_U32 (Img, 16#88#, 0);            --  timestamp
               Put_U32 (Img, 16#8C#, 0);            --  symbol table
               Put_U32 (Img, 16#90#, 0);            --  symbols
               Put_U16 (Img, 16#94#, 16#F0#);       --  optional size
               Put_U16 (Img, 16#96#, 16#0022#);     --  characteristics

               --  Optional header (PE32+).
               Put_U16 (Img, 16#98#, 16#20B#);      --  magic
               Put_U8  (Img, 16#9A#, 2);            --  linker major
               Put_U8  (Img, 16#9B#, 0);
               Put_U32 (Img, 16#9C#, Code_Size);    --  size of code
               Put_U32 (Img, 16#A0#, Init_Size);    --  init data
               Put_U32 (Img, 16#A4#, Uninit_Size);  --  uninit data
               Put_U32 (Img, 16#A8#, Entry_Point);  --  entry point
               Put_U32 (Img, 16#AC#, Base_Code);    --  base of code
               Put_U64 (Img, 16#B0#, 0);            --  image base (base-0 RVAs)
               Put_U32 (Img, 16#B8#, Section_Align);
               Put_U32 (Img, 16#BC#, File_Align);
               --  versions at 0xC0 .. 0xCB
               Put_U32 (Img, 16#CC#, 0);            --  win32 version
               Put_U32 (Img, 16#D0#, Size_Of_Image);
               Put_U32 (Img, 16#D4#, U64 (Header_Size));
               --  checksum at 0xD8, filled in later
               Put_U16 (Img, 16#DC#, 10);           --  EFI application
               Put_U16 (Img, 16#DE#, 0);            --  dll characteristics
               Put_U64 (Img, 16#E0#, 16#100000#);   --  stack reserve
               Put_U64 (Img, 16#E8#, 16#1000#);     --  stack commit
               Put_U64 (Img, 16#F0#, 16#100000#);   --  heap reserve
               Put_U64 (Img, 16#F8#, 16#1000#);     --  heap commit
               Put_U32 (Img, 16#100#, 0);           --  loader flags
               Put_U32 (Img, 16#104#, 16);          --  number of dirs
               --  data directories start at 0x108
               if Reloc_Total > 0 then
                  Put_U32 (Img, 16#108# + 5 * 8,
                           Pe (Reloc_Index).Virtual_Address);
                  Put_U32 (Img, 16#108# + 5 * 8 + 4, Reloc_Total);
               end if;

               --  Section headers start at optional + 0xF0.
               declare
                  Headers : constant Natural := 16#98# + 16#F0#;
               begin
                  for I in 1 .. Num_Sections loop
                     declare
                        Base : constant Natural :=
                          Headers + (I - 1) * 40;
                     begin
                        for J in 1 .. Pe (I).Name_Len loop
                           Img (Base + J) :=
                             Character'Pos (Pe (I).Name (J));
                        end loop;
                        Put_U32 (Img, Base + 8, Pe (I).Virtual_Size);
                        Put_U32 (Img, Base + 12, Pe (I).Virtual_Address);
                        Put_U32 (Img, Base + 16, Pe (I).Raw_Size);
                        Put_U32 (Img, Base + 20, Pe (I).Raw_Offset);
                        Put_U32 (Img, Base + 36, U64 (Pe (I).Characteristics));
                     end;
                  end loop;
               end;

               --  Copy section contents.
               for I in 1 .. Num_Sections loop
                  if Pe (I).Raw_Size > 0 and then I /= Reloc_Index then
                     declare
                        S : constant Section :=
                          Sections.Element (Pe (I).Elf_Index);
                        Dest : constant Natural :=
                          Natural (Pe (I).Raw_Offset);
                     begin
                        for J in 0 .. Natural (S.Size) - 1 loop
                           Img (Dest + J + 1) :=
                             File_Data (Natural (S.Offset) + J + 1);
                        end loop;
                     end;
                  end if;
               end loop;

               --  Emit base relocation blocks.
               if Reloc_Total > 0 then
                  declare
                     Cursor : Natural :=
                       Natural (Pe (Reloc_Index).Raw_Offset);
                     I : Natural := 0;
                  begin
                     while I <= Relocs.Last_Index loop
                        declare
                           Page  : constant U64 :=
                             Relocs.Element (I) and not 16#FFF#;
                           First : constant Natural := I;
                           Count : U64 := 0;
                        begin
                           while I <= Relocs.Last_Index
                             and then
                               (Relocs.Element (I) and not 16#FFF#) = Page
                           loop
                              Count := Count + 1;
                              I := I + 1;
                           end loop;
                           Put_U32 (Img, Cursor, Page);
                           Put_U32 (Img, Cursor + 4,
                                    Align_Up (8 + 2 * Count, 4));
                           for J in 0 .. Natural (Count) - 1 loop
                              declare
                                 Off : constant U64 :=
                                   Relocs.Element (First + J) and 16#FFF#;
                              begin
                                 Put_U16 (Img, Cursor + 8 + 2 * J,
                                          Shift_Left (U64 (10), 12) or Off);
                              end;
                           end loop;
                           Cursor := Cursor + Natural
                             (Align_Up (8 + 2 * Count, 4));
                        end;
                     end loop;
                  end;
               end if;

               --  PE checksum.
               declare
                  Sum : U64 := 0;
                  W   : U64;
                  I   : Natural := 1;
               begin
                  while I <= File_Size loop
                     W := U64 (Img (I));
                     if I < File_Size then
                        W := W + U64 (Img (I + 1)) * 256;
                     end if;
                     Sum := Sum + W;
                     Sum := (Sum and 16#FFFF#) + Shift_Right (Sum, 16);
                     I := I + 2;
                  end loop;
                  Sum := (Sum and 16#FFFF#) + Shift_Right (Sum, 16);
                  Put_U32 (Img, 16#D8#,
                           (Sum + U64 (File_Size)) and 16#FFFF_FFFF#);
               end;

               --  Write the result.
               declare
                  Out_F : File_Type;
                  Raw : Stream_Element_Array
                    (0 .. Stream_Element_Offset (File_Size - 1));
               begin
                  for I in 1 .. File_Size loop
                     Raw (Stream_Element_Offset (I - 1)) :=
                       Stream_Element (Img (I));
                  end loop;
                  Stream_IO.Create (Out_F, Stream_IO.Out_File, Output_Name);
                  Stream_IO.Write (Out_F, Raw);
                  Stream_IO.Close (Out_F);
               end;

               if Verbose then
                  Ada.Text_IO.Put_Line
                    ("elf2efi: " & Output_Name
                     & ": " & Natural'Image (File_Size) & " bytes, "
                     & Natural'Image (Num_Sections) & " sections, "
                     & Natural'Image (Natural (Relocs.Length))
                     & " base relocations");
               end if;
            end;
         end;
      end;
   end;
   end Convert;

   ------------------------------------------------------------------------
   --  Command line
   ------------------------------------------------------------------------

   Input_Name  : String (1 .. 1024) := (others => ' ');
   Input_Len   : Natural := 0;
   Output_Name : String (1 .. 1024) := (others => ' ');
   Output_Len  : Natural := 0;
   Verbose     : Boolean := False;

   procedure Usage is
   begin
      Ada.Text_IO.Put_Line
        ("usage: elf2efi [-v] [-o OUTPUT] INPUT.elf");
      Ada.Text_IO.Put_Line
        ("  Converts a zero-based ELF64 x86-64 image with .rela.dyn");
      Ada.Text_IO.Put_Line
        ("  relocation entries into a PE32+ UEFI application.");
   end Usage;

begin
   if Ada.Command_Line.Argument_Count = 0 then
      Usage;
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   declare
      I : Positive := 1;
   begin
      while I <= Ada.Command_Line.Argument_Count loop
         declare
            Arg : constant String := Ada.Command_Line.Argument (I);
         begin
            if Arg = "-h" or else Arg = "--help" then
               Usage;
               return;
            elsif Arg = "-v" then
               Verbose := True;
            elsif Arg = "-o" then
               I := I + 1;
               if I > Ada.Command_Line.Argument_Count then
                  Fail ("-o needs an argument");
               end if;
               declare
                  Out_Arg : constant String :=
                    Ada.Command_Line.Argument (I);
               begin
                  Output_Len := Out_Arg'Length;
                  Output_Name (1 .. Output_Len) := Out_Arg;
               end;
            elsif Arg'Length > 0 and then Arg (Arg'First) = '-' then
               Fail ("unknown option " & Arg);
            else
               if Input_Len /= 0 then
                  Fail ("more than one input file given");
               end if;
               Input_Len := Arg'Length;
               Input_Name (1 .. Input_Len) := Arg;
            end if;
            I := I + 1;
         end;
      end loop;
   end;

   if Input_Len = 0 then
      Fail ("no input file given");
   end if;

   if Output_Len = 0 then
      --  Replace a trailing ".elf" with ".efi", otherwise append ".efi".
      declare
         Base : constant String := Input_Name (1 .. Input_Len);
      begin
         if Input_Len > 4
           and then Base (Input_Len - 3 .. Input_Len) = ".elf"
         then
            Output_Len := Input_Len - 4 + 4;
            Output_Name (1 .. Output_Len - 4) := Base (1 .. Input_Len - 4);
            Output_Name (Output_Len - 3 .. Output_Len) := ".efi";
         else
            Output_Len := Input_Len + 4;
            Output_Name (1 .. Input_Len) := Base;
            Output_Name (Input_Len + 1 .. Output_Len) := ".efi";
         end if;
      end;
   end if;

   Convert (Input_Name (1 .. Input_Len), Output_Name (1 .. Output_Len),
            Verbose);

exception
   when Conversion_Error =>
      null;
   when E : others =>
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                            "elf2efi: " & Ada.Exceptions.Exception_Message (E));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Elf2Efi;
