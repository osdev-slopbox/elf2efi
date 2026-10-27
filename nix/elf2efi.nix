# Standalone build of the elf2efi converter.
{ lib
, stdenv
, gnat
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "elf2efi";
  version = "0.1.0";

  src = ../.;

  nativeBuildInputs = [ gnat ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    mkdir -p build
    gnatmake -O2 -D build -o build/elf2efi tools/elf2efi.adb
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 build/elf2efi $out/bin/elf2efi
    runHook postInstall
  '';

  meta = {
    description = "Convert Ada-EFI ELF64 images to PE32+ UEFI applications";
    homepage = "https://github.com/osdev-slopbox/elf2efi";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
})
