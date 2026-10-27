# Build the Ada-EFI library, converter, and example UEFI applications.
{ lib
, stdenv
, gnat
, gnumake
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "ada-efi";
  version = "0.1.0";

  src = ../.;

  nativeBuildInputs = [ gnat gnumake ];

  dontConfigure = true;
  # Object files must keep their symbols for downstream linking.
  dontStrip = true;

  buildPhase = ''
    runHook preBuild
    make BUILD=build -j"$NIX_BUILD_CORES"
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin \
             $out/include/ada-efi \
             $out/lib/ada-efi \
             $out/share/ada-efi/examples \
             $out/nix-support

    cp build/efi*.o build/crt0.o $out/lib/ada-efi/
    cp src/*.ads $out/include/ada-efi/
    cp src/elf_x86_64_efi.lds $out/share/ada-efi/
    cp build/*.efi $out/share/ada-efi/examples/
    install -Dm755 build/elf2efi $out/bin/elf2efi

    cat > $out/nix-support/setup-hook <<EOF
    export ADA_EFI_INCLUDE="$out/include/ada-efi"
    export ADA_EFI_LIB="$out/lib/ada-efi"
    export ADA_EFI_LDS="$out/share/ada-efi/elf_x86_64_efi.lds"
    export ADA_EFI_ELF2EFI="$out/bin/elf2efi"
    export ADA_EFI_ADAFLAGS="-c -gnatp -O2 -fPIE -fno-strict-aliasing -mabi=ms"
    addToSearchPath PATH "$out/bin"
    EOF

    runHook postInstall
  '';

  meta = {
    description = "UEFI application library for Ada with an ELF to PE32+ converter";
    homepage = "https://github.com/osdev-slopbox/elf2efi";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
})
