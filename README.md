# Ada-EFI

A small UEFI application library for Ada in the spirit of GNU-EFI, plus a
self-hosted Ada ELF64-to-PE32+ converter.

It includes UEFI base types and tables, console I/O, memory allocation,
loaded-image access, simple file-system support, and three examples:
`hello` (console/output), `sysinfo` (firmware, config table, memory map), and
`cat` (read a file from the boot volume).

## Requirements

- GNAT supporting `-mabi=ms` (tested with GNAT 16.2.0)
- GNU binutils `ld` and GNU Make
- For `make test`/`make run`: QEMU, OVMF, `mtools`, and `dosfstools`

x86-64 UEFI only.

## Build and test

```sh
make                 # build/*.efi
make test            # boot each example under QEMU/OVMF
make clean
```

Boot one application directly:

```sh
./test/run-qemu.sh build/hello.efi "Hello from Ada!"
```

Copy extra files onto the ESP with `--file HOST:ESP`:

```sh
./test/run-qemu.sh build/cat.efi "Hello from Ada-EFI!" \
    --file test/README.TXT:/EFI/BOOT/README.TXT
```

Firmware is auto-detected, or set `OVMF_CODE`/`OVMF_VARS`, `OVMF_DIR`,
`QEMU`, or `QEMU_TIMEOUT`.

## Writing an application

An application exports an Ada `Efi_Main` as the C symbol `efi_main`:

```ada
--  apps/demo.ads
with EFI;

package Demo is
   function Efi_Main
     (Image : EFI.Handle;
      ST    : EFI.System_Table_Access) return EFI.Status;
   pragma Export (C, Efi_Main, "efi_main");
end Demo;
```

```ada
--  apps/demo.adb
with EFI; use EFI;
with EFI.Library; use EFI.Library;
with EFI.Console; use EFI.Console;

package body Demo is
   function Efi_Main
     (Image : EFI.Handle;
      ST    : EFI.System_Table_Access) return EFI.Status
   is
   begin
      Initialize_Lib (Image, ST);
      Print_Line ("Hello from Ada!");
      return EFI_SUCCESS;
   end Efi_Main;
end Demo;
```

Add `demo` to `APPS` in the `Makefile`, then run `make`.
`Initialize_Lib` (GNU-EFI's `InitializeLib`) must be called before using the
convenience packages.

## Packages

| Package            | Purpose |
|--------------------|---------|
| `EFI`              | Types, status codes, GUIDs, system/boot/runtime tables, protocols |
| `EFI.Library`      | Global state, protocol lookup, configuration table |
| `EFI.Console`      | Print, hex/decimal/status/GUID output, screen control |
| `EFI.Memory`       | Pool/page allocation, copy/fill/zero |
| `EFI.Loaded_Image` | Image base/size, device handle, load options |
| `EFI.Files`        | Open/read/write/close via `EFI_SIMPLE_FILE_SYSTEM_PROTOCOL` |
| `EFI.Util`         | Wide strings and UTF-8 to UCS-2 conversion |
| `EFI.Runtime`      | Freestanding `memcpy`, `memset`, `memmove` |

## How it works

1. Ada is compiled with `-mabi=ms` to match the UEFI Microsoft x64 ABI and
   `-gnatp` to avoid runtime checks.
2. The application links as a PIE at virtual address 0, so ELF virtual
   addresses are also PE RVAs.
3. GNU `ld` records absolute pointers as `R_X86_64_RELATIVE` in `.rela.dyn`.
   `elf2efi` converts these to PE `.reloc` DIR64 entries and writes
   `ImageBase` as 0.
4. `src/crt0.S` is the PE entry point; it calls `efi_main` and returns the
   status to the firmware.

## Limitations

- No tasking, exceptions, or full GNAT runtime elaboration.
- Only the protocols used by the examples are declared; add more records in
  `src/efi.ads`.
- `elf2efi` expects the section layout from `src/elf_x86_64_efi.lds` and only
  handles `R_X86_64_RELATIVE` relocations.
