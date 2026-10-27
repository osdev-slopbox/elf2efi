# Build a downstream UEFI application against Ada-EFI.
#
# The source directory must contain <package>.ads and <package>.adb, where
# <package> is the lower-case Ada unit file name (for example "hello").
{ lib
, stdenv
, gnat
, adaEfi
}:

{ name
, src
, package ? name
}:

stdenv.mkDerivation {
  pname = name;
  version = "0.1.0";

  inherit src;

  nativeBuildInputs = [ gnat adaEfi ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    gcc $ADA_EFI_ADAFLAGS -I. -I"$ADA_EFI_INCLUDE" -c "${package}.adb" -o "${package}.o"

    ld -pie -nostdlib -T "$ADA_EFI_LDS" -o "${name}.elf" \
      "$ADA_EFI_LIB/crt0.o" "$ADA_EFI_LIB"/efi*.o "${package}.o"

    "$ADA_EFI_ELF2EFI" -v -o "${name}.efi" "${name}.elf"

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 "${name}.efi" "$out/share/uefi-apps/${name}.efi"
    runHook postInstall
  '';

  meta = {
    description = "UEFI application built with Ada-EFI";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
