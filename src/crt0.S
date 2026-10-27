/* UEFI x86-64 entry stub.
 *
 * Firmware calls the PE entry point with the Microsoft x64 convention:
 *   RCX = EFI_HANDLE ImageHandle
 *   RDX = EFI_SYSTEM_TABLE *SystemTable
 * All Ada code is compiled with -mabi=ms, so we can call efi_main directly.
 * 32 bytes of shadow space plus 8 bytes of alignment pad are reserved.
 */

        .text
        .globl  _start
        .type   _start, @function
_start:
        subq    $40, %rsp
        call    efi_main
        addq    $40, %rsp
        ret
        .size   _start, .-_start

        .section .note.GNU-stack,"",@progbits
