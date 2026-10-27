/* Linker script for Ada-EFI applications.
 *
 * The image is linked at virtual address 0, so every virtual address is
 * also a PE RVA.  elf2efi converts the .rela.dyn base relocations that
 * GNU ld emits into a PE .reloc section.
 *
 * Sections must be page aligned because each becomes a PE section.
 */

OUTPUT_FORMAT(elf64-x86-64)
OUTPUT_ARCH(i386:x86-64)
ENTRY(_start)

SECTIONS
{
  . = 0x1000;
  .text : {
    *(.text .text.*)
    *(.plt .plt.*)
  }

  . = ALIGN(0x1000);
  .rodata : {
    *(.rodata .rodata.*)
    *(.data.rel.ro .data.rel.ro.*)
  }

  . = ALIGN(0x1000);
  .data : {
    *(.data .data.*)
    *(.got .got.*)
  }

  . = ALIGN(0x1000);
  .bss : {
    *(.bss .bss.*)
    *(COMMON)
  }

  . = ALIGN(0x1000);
  .rela.dyn : {
    *(.rela.dyn)
    *(.rela.plt)
  }

  /DISCARD/ : {
    *(.eh_frame .eh_frame.*)
    *(.note .note.*)
    *(.comment)
    *(.interp)
    *(.dynamic)
    *(.dynsym)
    *(.dynstr)
    *(.hash)
    *(.gnu.hash)
    *(.gnu.version .gnu.version_*)
    *(.symtab)
    *(.strtab)
  }
}
