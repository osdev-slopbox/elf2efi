# Ada-EFI -- UEFI applications in Ada, in the spirit of GNU-EFI.

BUILD      ?= build
GNAT       ?= gcc
LD         ?= ld
GNATMAKE   ?= gnatmake

ADAFLAGS   = -c -gnatp -O2 -fPIE -fno-strict-aliasing -mabi=ms -Isrc -I$(BUILD)
CFLAGS     = -c -fPIE
LDFLAGS    = -pie -nostdlib -T src/elf_x86_64_efi.lds

LIB_OBJECTS = \
  $(BUILD)/efi.o \
  $(BUILD)/efi-runtime.o \
  $(BUILD)/efi-util.o \
  $(BUILD)/efi-library.o \
  $(BUILD)/efi-console.o \
  $(BUILD)/efi-memory.o \
  $(BUILD)/efi-loaded_image.o \
  $(BUILD)/efi-files.o

APPS  = hello sysinfo cat
EFIS  = $(APPS:%=$(BUILD)/%.efi)
SPECS = $(wildcard src/*.ads)

.SECONDARY:

.PHONY: all clean test run

all: $(EFIS)

$(BUILD):
	mkdir -p $(BUILD)

# The base package is a spec only.
$(BUILD)/efi.o: src/efi.ads | $(BUILD)
	$(GNAT) $(ADAFLAGS) $< -o $@

$(BUILD)/%.o: src/%.adb src/%.ads $(SPECS) | $(BUILD)
	$(GNAT) $(ADAFLAGS) $< -o $@

$(BUILD)/crt0.o: src/crt0.S | $(BUILD)
	$(GNAT) $(CFLAGS) $< -o $@

$(BUILD)/%.o: apps/%.adb apps/%.ads $(LIB_OBJECTS) $(SPECS) | $(BUILD)
	$(GNAT) $(ADAFLAGS) -Iapps $< -o $@

$(BUILD)/elf2efi: tools/elf2efi.adb | $(BUILD)
	$(GNATMAKE) -O2 -D $(BUILD) -o $@ $<

$(BUILD)/%.elf: $(BUILD)/crt0.o $(LIB_OBJECTS) $(BUILD)/%.o
	$(LD) $(LDFLAGS) -o $@ $^

$(BUILD)/%.efi: $(BUILD)/%.elf $(BUILD)/elf2efi
	$(BUILD)/elf2efi -v -o $@ $<

test: $(EFIS)
	./test/run-qemu.sh $(BUILD)/hello.efi "Hello from Ada!"
	./test/run-qemu.sh $(BUILD)/sysinfo.efi "Memory map:"
	./test/run-qemu.sh $(BUILD)/cat.efi "Hello from Ada-EFI!" \
	  --file test/README.TXT:/EFI/BOOT/README.TXT

run: $(BUILD)/hello.efi
	./test/run-qemu.sh $(BUILD)/hello.efi "Hello from Ada!" --keep

clean:
	rm -rf $(BUILD) test/out
